# Deploy-AVD-EntraIDOnly.ps1
# Deploys an end-to-end Azure Virtual Desktop environment (Entra ID-joined, no on-premises AD).
# Prerequisites: az CLI authenticated, desktopvirtualization extension unavailable - script uses az rest.
#
# Usage:
#   .\Deploy-AVD-EntraIDOnly.ps1 `
#       -SubscriptionId "00f08d69-e072-45e3-841a-bcec85e47411" `
#       -ResourceGroup  "dwp-lab-rg" `
#       -Location       "centralus" `
#       -AssigneeUPN    "p21@zippyops.in"

param(
    [Parameter(Mandatory)][string]$SubscriptionId,
    [Parameter(Mandatory)][string]$ResourceGroup,
    [Parameter(Mandatory)][string]$Location,
    [Parameter(Mandatory)][string]$AssigneeUPN,

    [string]$HostPoolName      = "POOL-FIN-01",
    [string]$AppGroupName      = "POOL-FIN-01-DAG",
    [string]$WorkspaceName     = "FinBridge-Workspace",
    [string]$VNetName          = "dwp-avd-vnet",
    [string]$SubnetName        = "avd-subnet",
    [string]$NatGwName         = "avd-natgw",
    [string]$NatGwPipName      = "avd-natgw-pip",
    [string]$VmName            = "avd-fin-sh01",
    [string]$VmSize            = "Standard_B2ms",
    [string]$AdminUsername     = "avdadmin",
    [string]$VnetPrefix        = "10.10.0.0/16",
    [string]$SubnetPrefix      = "10.10.1.0/24",
    [string]$DscPackageUrl     = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02714.342.zip"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$baseUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup"

function Invoke-Arm($method, $relPath, $body = $null, $apiVersion) {
    $url = "$baseUrl/$relPath`?api-version=$apiVersion"
    if ($body) {
        $bodyFile = [System.IO.Path]::GetTempFileName()
        $body | Out-File $bodyFile -Encoding utf8 -NoNewline
        az rest --method $method --url $url --body "@$bodyFile" -o json | ConvertFrom-Json
        Remove-Item $bodyFile -Force
    } else {
        az rest --method $method --url $url -o json | ConvertFrom-Json
    }
}

# ── 1. Host pool ─────────────────────────────────────────────────────────────
Write-Host "`n[1/9] Creating host pool $HostPoolName..." -ForegroundColor Cyan
$expiry = [System.DateTime]::UtcNow.AddHours(24).ToString("yyyy-MM-ddTHH:mm:ssZ")
$hpBody = @{
    location   = $Location
    properties = @{
        hostPoolType               = "Pooled"
        loadBalancerType           = "BreadthFirst"
        maxSessionLimit            = 5
        preferredAppGroupType      = "Desktop"
        registrationInfo           = @{
            expirationTime             = $expiry
            registrationTokenOperation = "Update"
        }
    }
} | ConvertTo-Json -Depth 6

Invoke-Arm PUT "providers/Microsoft.DesktopVirtualization/hostPools/$HostPoolName" $hpBody "2022-09-09" | Out-Null
Write-Host "  Host pool created." -ForegroundColor Green

# ── 2. Application group ──────────────────────────────────────────────────────
Write-Host "`n[2/9] Creating application group $AppGroupName..." -ForegroundColor Cyan
$hpArmPath = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.DesktopVirtualization/hostPools/$HostPoolName"
$agBody = @{
    location   = $Location
    properties = @{
        applicationGroupType = "Desktop"
        hostPoolArmPath      = $hpArmPath
        friendlyName         = "FinBridge Desktop"
    }
} | ConvertTo-Json -Depth 4

Invoke-Arm PUT "providers/Microsoft.DesktopVirtualization/applicationGroups/$AppGroupName" $agBody "2022-09-09" | Out-Null
Write-Host "  Application group created." -ForegroundColor Green

# ── 3. Workspace ──────────────────────────────────────────────────────────────
Write-Host "`n[3/9] Creating workspace $WorkspaceName..." -ForegroundColor Cyan
$agArmId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.DesktopVirtualization/applicationGroups/$AppGroupName"
$wsBody = @{
    location   = $Location
    properties = @{
        friendlyName              = "FinBridge Workspace"
        applicationGroupReferences = @($agArmId)
    }
} | ConvertTo-Json -Depth 4

Invoke-Arm PUT "providers/Microsoft.DesktopVirtualization/workspaces/$WorkspaceName" $wsBody "2022-09-09" | Out-Null
Write-Host "  Workspace created." -ForegroundColor Green

# ── 4. VNet + subnet ──────────────────────────────────────────────────────────
Write-Host "`n[4/9] Creating VNet and subnet..." -ForegroundColor Cyan
az network vnet create `
    --name $VNetName --resource-group $ResourceGroup --location $Location `
    --address-prefix $VnetPrefix `
    --subnet-name $SubnetName --subnet-prefix $SubnetPrefix | Out-Null
Write-Host "  VNet/subnet created." -ForegroundColor Green

# ── 5. NAT gateway (required – default outbound SNAT retired 30 Sep 2025) ─────
Write-Host "`n[5/9] Creating NAT gateway for outbound internet..." -ForegroundColor Cyan
az network public-ip create `
    --resource-group $ResourceGroup --name $NatGwPipName `
    --location $Location --sku Standard --allocation-method Static | Out-Null
az network nat gateway create `
    --resource-group $ResourceGroup --name $NatGwName `
    --location $Location --public-ip-addresses $NatGwPipName --idle-timeout 10 | Out-Null
az network vnet subnet update `
    --resource-group $ResourceGroup --vnet-name $VNetName --name $SubnetName `
    --nat-gateway $NatGwName | Out-Null
Write-Host "  NAT gateway attached to subnet." -ForegroundColor Green

# ── 6. Session host VM ────────────────────────────────────────────────────────
Write-Host "`n[6/9] Creating session host VM $VmName..." -ForegroundColor Cyan
$adminPass = "AvdL@b-$(Get-Random -Minimum 10000 -Maximum 99999)!"
Write-Host "  Admin password stored in variable `$adminPass (not logged)."

az vm create `
    --resource-group $ResourceGroup --name $VmName `
    --image "MicrosoftWindowsDesktop:windows-11:win11-24h2-avd:latest" `
    --size $VmSize `
    --vnet-name $VNetName --subnet $SubnetName `
    --admin-username $AdminUsername --admin-password $adminPass `
    --security-type TrustedLaunch --enable-secure-boot true --enable-vtpm true `
    --license-type Windows_Client `
    --public-ip-address '""' --nsg '""' `
    --os-disk-name "$VmName-osdisk" | Out-Null

Write-Host "  VM created. Enabling system-assigned managed identity..." -ForegroundColor Green
az vm identity assign --resource-group $ResourceGroup --name $VmName `
    --identities "[system]" | Out-Null
Write-Host "  Managed identity assigned." -ForegroundColor Green

# ── 7. AVD agent (DSC extension) ──────────────────────────────────────────────
Write-Host "`n[7/9] Installing AVD agent via DSC extension..." -ForegroundColor Cyan
$regToken = az rest --method POST `
    --url "$baseUrl/providers/Microsoft.DesktopVirtualization/hostPools/$HostPoolName/retrieveRegistrationToken?api-version=2022-09-09" `
    --query "token" -o tsv

$dscBody = @{
    location   = $Location
    properties = @{
        publisher              = "Microsoft.Powershell"
        type                   = "DSC"
        typeHandlerVersion     = "2.73"
        autoUpgradeMinorVersion = $true
        settings               = @{
            modulesUrl            = $DscPackageUrl
            configurationFunction = "Configuration.ps1\AddSessionHost"
            properties            = @{
                hostPoolName           = $HostPoolName
                registrationInfoToken  = $regToken
                aadJoin                = $true
                useAgentDownloadEndpoint = $true
                mdmId                  = ""
            }
        }
    }
} | ConvertTo-Json -Depth 8

$dscFile = [System.IO.Path]::GetTempFileName()
$dscBody | Out-File $dscFile -Encoding utf8 -NoNewline

az rest --method PUT `
    --url "$baseUrl/providers/Microsoft.Compute/virtualMachines/$VmName/extensions/Microsoft.PowerShell.DSC?api-version=2023-03-01" `
    --body "@$dscFile" | Out-Null
Remove-Item $dscFile -Force

Write-Host "  DSC extension submitted. Waiting for provisioning (15-25 min)..." -ForegroundColor Yellow

$timeout = [System.DateTime]::UtcNow.AddMinutes(30)
do {
    Start-Sleep -Seconds 60
    $state = az vm extension show --resource-group $ResourceGroup --vm-name $VmName `
        --name "Microsoft.PowerShell.DSC" --query "provisioningState" -o tsv
    Write-Host "  DSC state: $state  ($(Get-Date -Format 'HH:mm:ss'))"
} while ($state -eq "Creating" -and [System.DateTime]::UtcNow -lt $timeout)

if ($state -ne "Succeeded") {
    Write-Error "DSC extension failed with state '$state'. Check VM extension logs."
}
Write-Host "  DSC extension succeeded." -ForegroundColor Green

# ── 8. Entra ID join (AADLoginForWindows) ─────────────────────────────────────
Write-Host "`n[8/9] Joining VM to Entra ID (AADLoginForWindows)..." -ForegroundColor Cyan
$aadBody = '{"location":"' + $Location + '","properties":{"publisher":"Microsoft.Azure.ActiveDirectory","type":"AADLoginForWindows","typeHandlerVersion":"2.0","autoUpgradeMinorVersion":true,"settings":{"mdmId":""}}}'
$aadFile = [System.IO.Path]::GetTempFileName()
$aadBody | Out-File $aadFile -Encoding utf8 -NoNewline

az rest --method PUT `
    --url "$baseUrl/providers/Microsoft.Compute/virtualMachines/$VmName/extensions/AADLoginForWindows?api-version=2023-03-01" `
    --body "@$aadFile" | Out-Null
Remove-Item $aadFile -Force

$timeout = [System.DateTime]::UtcNow.AddMinutes(10)
do {
    Start-Sleep -Seconds 30
    $aadState = az vm extension show --resource-group $ResourceGroup --vm-name $VmName `
        --name "AADLoginForWindows" --query "provisioningState" -o tsv
    Write-Host "  AADLoginForWindows state: $aadState  ($(Get-Date -Format 'HH:mm:ss'))"
} while ($aadState -eq "Creating" -and [System.DateTime]::UtcNow -lt $timeout)

if ($aadState -ne "Succeeded") {
    Write-Error "AADLoginForWindows failed. Verify managed identity is assigned and tenant supports device registration."
}
Write-Host "  Entra ID join succeeded." -ForegroundColor Green

# ── 9. Role assignments for end user ──────────────────────────────────────────
Write-Host "`n[9/9] Assigning roles to $AssigneeUPN..." -ForegroundColor Cyan
$userOid = az ad user show --id $AssigneeUPN --query "id" -o tsv

az role assignment create `
    --assignee $userOid --role "Desktop Virtualization User" `
    --scope "$baseUrl/providers/Microsoft.DesktopVirtualization/applicationGroups/$AppGroupName" | Out-Null

az role assignment create `
    --assignee $userOid --role "Virtual Machine User Login" `
    --scope "$baseUrl/providers/Microsoft.Compute/virtualMachines/$VmName" | Out-Null

Write-Host "  Roles assigned." -ForegroundColor Green

# ── Final verification ────────────────────────────────────────────────────────
Write-Host "`n=== Session host final status ===" -ForegroundColor Cyan
az rest --method GET `
    --url "$baseUrl/providers/Microsoft.DesktopVirtualization/hostPools/$HostPoolName/sessionHosts/$VmName`?api-version=2022-09-09" `
    --query "{status:properties.status,lastHeartbeat:properties.lastHeartBeat,agentVersion:properties.agentVersion,osVersion:properties.osVersion}" `
    -o table

Write-Host "`nHealth checks:" -ForegroundColor Cyan
az rest --method GET `
    --url "$baseUrl/providers/Microsoft.DesktopVirtualization/hostPools/$HostPoolName/sessionHosts/$VmName`?api-version=2022-09-09" `
    --query "properties.sessionHostHealthCheckResults[].{Check:healthCheckName,Result:healthCheckResult}" `
    -o table
