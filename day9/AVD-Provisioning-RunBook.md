# AVD Provisioning Run Book — Entra ID Only (No On-Premises AD)

**Date:** 2026-08-13  
**Engineer:** traininguser23@zippyops.in  
**Subscription:** `00f08d69-e072-45e3-841a-bcec85e47411` (labs23)  
**Resource group:** `dwp-lab-rg` · Region: `centralus`  
**Tenant (M365):** `zippyops.in` (TenantId: `fa8443c6-5a39-4df5-a018-9c876455adf9`)  
**End-user account:** `p21@zippyops.in`

---

## Architecture

```
FinBridge-Workspace
  └── POOL-FIN-01-DAG  (Desktop application group)
        └── POOL-FIN-01  (Pooled host pool — BreadthFirst, max 5 sessions)
              └── avd-fin-sh01  (Session host — Win11 24H2 AVD, Standard_B2ms)
                    VNet: dwp-avd-vnet / avd-subnet (10.10.1.0/24)
                    Outbound: avd-natgw  →  52.242.132.85
                    Identity: Entra ID joined (AADLoginForWindows v2, Secure VM Join)
                    Security: TrustedLaunch — SecureBoot ✓  vTPM ✓
```

---

## Pre-flight check

Before any resource was created, the signed-in identity and its permissions were confirmed.

```powershell
# Confirm active subscription
az account show --query "{subscriptionId:id, name:name, tenantId:tenantId, userName:user.name}" -o table

# Get signed-in user's object ID
$myOid = az ad signed-in-user show --query id -o tsv

# Confirm role at subscription scope
az role assignment list --assignee $myOid `
  --scope "/subscriptions/00f08d69-e072-45e3-841a-bcec85e47411" `
  --include-inherited --query "[].{Role:roleDefinitionName, Scope:scope}" -o table
```

**Result:** `Owner` at subscription scope — sufficient to create all resources and make role assignments.

> If the signed-in identity does not hold Owner or a custom role that includes `Microsoft.Authorization/roleAssignments/write`, stop here. Role assignments (steps 9) will fail silently or with a permissions error.

---

## Step 1 — Create the host pool

**Why:** The host pool is the top-level AVD object that defines load balancing behaviour and session limits. All session hosts register against it.

```powershell
$expiry = [System.DateTime]::UtcNow.AddHours(24).ToString("yyyy-MM-ddTHH:mm:ssZ")
$json = '{"location":"centralus","properties":{"hostPoolType":"Pooled","loadBalancerType":"BreadthFirst","maxSessionLimit":5,"preferredAppGroupType":"Desktop","registrationInfo":{"expirationTime":"' + $expiry + '","registrationTokenOperation":"Update"}}}'
$json | Out-File "$env:TEMP\hostpool.json" -Encoding utf8 -NoNewline

az rest --method PUT `
  --url "https://management.azure.com/subscriptions/00f08d69-e072-45e3-841a-bcec85e47411/resourceGroups/dwp-lab-rg/providers/Microsoft.DesktopVirtualization/hostPools/POOL-FIN-01?api-version=2022-09-09" `
  --body "@$env:TEMP\hostpool.json" `
  --query "{name:name,hostPoolType:properties.hostPoolType,loadBalancerType:properties.loadBalancerType,maxSessionLimit:properties.maxSessionLimit}" -o table
```

**Verification:**
```
Name         HostPoolType    LoadBalancerType    MaxSessionLimit
-----------  --------------  ------------------  -----------------
POOL-FIN-01  Pooled          BreadthFirst        5
```

> **Note:** The `az desktopvirtualization` CLI extension was unavailable in this environment (interactive install prompt killed by terminal timeout). All AVD resources were created using `az rest` with the ARM API directly — this is a fully supported alternative.

---

## Step 2 — Create the Desktop application group

**Why:** Users are granted access to the published desktop through the application group, not the host pool directly.

```powershell
$hpPath = "/subscriptions/00f08d69-e072-45e3-841a-bcec85e47411/resourceGroups/dwp-lab-rg/providers/Microsoft.DesktopVirtualization/hostPools/POOL-FIN-01"
$json = '{"location":"centralus","properties":{"applicationGroupType":"Desktop","hostPoolArmPath":"' + $hpPath + '","friendlyName":"FinBridge Desktop"}}'
$json | Out-File "$env:TEMP\appgroup.json" -Encoding utf8 -NoNewline

az rest --method PUT `
  --url "https://management.azure.com/subscriptions/00f08d69-e072-45e3-841a-bcec85e47411/resourceGroups/dwp-lab-rg/providers/Microsoft.DesktopVirtualization/applicationGroups/POOL-FIN-01-DAG?api-version=2022-09-09" `
  --body "@$env:TEMP\appgroup.json" `
  --query "{name:name,type:properties.applicationGroupType}" -o table
```

**Verification:**
```
Name              Type
----------------  -------
POOL-FIN-01-DAG   Desktop
```

---

## Step 3 — Create the workspace and register the application group

**Why:** The workspace is what end users see in the AVD client (Remote Desktop app / web client). An application group must be registered to a workspace to appear there.

```powershell
$agId = "/subscriptions/00f08d69-e072-45e3-841a-bcec85e47411/resourceGroups/dwp-lab-rg/providers/Microsoft.DesktopVirtualization/applicationGroups/POOL-FIN-01-DAG"
$json = '{"location":"centralus","properties":{"friendlyName":"FinBridge Workspace","applicationGroupReferences":["' + $agId + '"]}}'
$json | Out-File "$env:TEMP\workspace.json" -Encoding utf8 -NoNewline

az rest --method PUT `
  --url "https://management.azure.com/subscriptions/00f08d69-e072-45e3-841a-bcec85e47411/resourceGroups/dwp-lab-rg/providers/Microsoft.DesktopVirtualization/workspaces/FinBridge-Workspace?api-version=2022-09-09" `
  --body "@$env:TEMP\workspace.json" `
  --query "{name:name,friendlyName:properties.friendlyName,appGroups:properties.applicationGroupReferences}" -o json
```

**Verification:**
```json
{
  "name": "FinBridge-Workspace",
  "friendlyName": "FinBridge Workspace",
  "appGroups": ["…/applicationGroups/POOL-FIN-01-DAG"]
}
```

---

## Step 4 — Create VNet and subnet

**Why:** The session host VM requires a virtual network. A dedicated subnet isolates AVD traffic and allows the NAT gateway (step 5) to be scoped to it.

```powershell
az network vnet create `
  --name "dwp-avd-vnet" --resource-group "dwp-lab-rg" --location "centralus" `
  --address-prefix "10.10.0.0/16" `
  --subnet-name "avd-subnet" --subnet-prefix "10.10.1.0/24"
```

**Verification:**
```
Vnet          Subnet      AddressSpace    SubnetPrefix
------------  ----------  --------------  --------------
dwp-avd-vnet  avd-subnet  10.10.0.0/16    10.10.1.0/24
```

---

## Step 5 — Create NAT gateway for outbound internet

**Why (critical):** Microsoft retired default outbound SNAT for new Azure VMs on **30 September 2025**. Any VM created after that date with no public IP has no outbound internet access unless a NAT gateway (or load balancer with outbound rules) is attached to its subnet. Without outbound access the DSC extension cannot download the AVD agent package from `wvdportalstorageblob.blob.core.windows.net`.

```powershell
# 1. Standard public IP for the NAT gateway
az network public-ip create `
  --resource-group "dwp-lab-rg" --name "avd-natgw-pip" --location "centralus" `
  --sku Standard --allocation-method Static

# 2. NAT gateway
az network nat gateway create `
  --resource-group "dwp-lab-rg" --name "avd-natgw" --location "centralus" `
  --public-ip-addresses "avd-natgw-pip" --idle-timeout 10

# 3. Associate with the AVD subnet
az network vnet subnet update `
  --resource-group "dwp-lab-rg" --vnet-name "dwp-avd-vnet" --name "avd-subnet" `
  --nat-gateway "avd-natgw"
```

**Verification:**
```
Name        NatGateway
----------  -----------------------------------------------------------
avd-subnet  …/natGateways/avd-natgw
```

---

## Step 6 — Create the session host VM

**Settings applied:**

| Setting | Value | Reason |
|---|---|---|
| Image | `win11-24h2-avd` | AVD-optimised Windows 11 24H2 multi-session |
| Size | `Standard_B2ms` | 2 vCPU / 8 GB — lab sizing |
| Security type | `TrustedLaunch` | Enables Secure Boot and vTPM |
| Secure Boot | `true` | Blocks unsigned boot firmware/drivers |
| vTPM | `true` | Required for Trusted Launch attestation |
| License type | `Windows_Client` | Azure Hybrid Benefit for multi-session Windows |
| Public IP | none (`""`) | Access only through AVD gateway |
| NSG | none (`""`) | No direct internet exposure; no inbound ports needed |

```powershell
$adminPass = "AvdL@b-$(Get-Random -Minimum 10000 -Maximum 99999)!"

az vm create `
  --resource-group "dwp-lab-rg" --name "avd-fin-sh01" `
  --image "MicrosoftWindowsDesktop:windows-11:win11-24h2-avd:latest" `
  --size "Standard_B2ms" `
  --vnet-name "dwp-avd-vnet" --subnet "avd-subnet" `
  --admin-username "avdadmin" --admin-password $adminPass `
  --security-type "TrustedLaunch" --enable-secure-boot true --enable-vtpm true `
  --license-type "Windows_Client" `
  --public-ip-address '""' --nsg '""' `
  --os-disk-name "avd-fin-sh01-osdisk"
```

Enable system-assigned managed identity immediately after creation (required by step 8):

```powershell
az vm identity assign `
  --resource-group "dwp-lab-rg" --name "avd-fin-sh01" `
  --identities "[system]"
```

**Verification:**
```
Name          Size           SecurityType    SecureBoot    Vtpm    Image           ProvisioningState
------------  -------------  --------------  ------------  ------  --------------  -----------------
avd-fin-sh01  Standard_B2ms  TrustedLaunch   True          True    win11-24h2-avd  Succeeded
```

---

## Step 7 — Install the AVD agent (DSC extension)

**Why:** The DSC extension downloads and installs the RD Agent and RD Agent Boot Loader inside the VM, then registers the VM with the host pool using the registration token. Setting `aadJoin: true` tells the RD Agent this is an Entra ID-only deployment (skips traditional AD domain join checks).

```powershell
# Retrieve registration token (valid 24 h)
$regToken = az rest --method POST `
  --url "https://management.azure.com/subscriptions/00f08d69-e072-45e3-841a-bcec85e47411/resourceGroups/dwp-lab-rg/providers/Microsoft.DesktopVirtualization/hostPools/POOL-FIN-01/retrieveRegistrationToken?api-version=2022-09-09" `
  --query "token" -o tsv

# Build DSC extension body
$dsc = [ordered]@{
  location   = "centralus"
  properties = [ordered]@{
    publisher              = "Microsoft.Powershell"
    type                   = "DSC"
    typeHandlerVersion     = "2.73"
    autoUpgradeMinorVersion = $true
    settings               = [ordered]@{
      modulesUrl            = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02714.342.zip"
      configurationFunction = "Configuration.ps1\AddSessionHost"
      properties            = [ordered]@{
        hostPoolName             = "POOL-FIN-01"
        registrationInfoToken    = $regToken
        aadJoin                  = $true
        useAgentDownloadEndpoint = $true
        mdmId                    = ""
      }
    }
  }
}
($dsc | ConvertTo-Json -Depth 10) | Out-File "$env:TEMP\dsc-ext.json" -Encoding utf8 -NoNewline

az rest --method PUT `
  --url "https://management.azure.com/subscriptions/00f08d69-e072-45e3-841a-bcec85e47411/resourceGroups/dwp-lab-rg/providers/Microsoft.Compute/virtualMachines/avd-fin-sh01/extensions/Microsoft.PowerShell.DSC?api-version=2023-03-01" `
  --body "@$env:TEMP\dsc-ext.json"
```

**Poll until Succeeded (15–25 min):**
```powershell
do {
    Start-Sleep -Seconds 60
    $state = az vm extension show --resource-group "dwp-lab-rg" --vm-name "avd-fin-sh01" `
        --name "Microsoft.PowerShell.DSC" --query "provisioningState" -o tsv
    Write-Host "DSC state: $state"
} while ($state -eq "Creating")
```

**Key log entries (from instance view) confirming success:**
```
06:01:52Z  Downloading configuration package
06:02:19Z  Extracting Configuration_1.0.02714.342.zip      ← download succeeded
06:02:30Z  ExecuteRdAgentInstallClient  received 96,571,392-byte response
06:09:43Z  ExecuteRdAgentInstallClient  completed in 434 seconds
06:09:44Z  DSC configuration completed.
06:09:48Z  Settings handler status to 'success'
```

---

## Step 8 — Entra ID join (AADLoginForWindows extension)

**Why:** The DSC `aadJoin: true` flag skips traditional domain join but does **not** perform the actual Entra ID device registration. `AADLoginForWindows` v2.0 does the Secure VM Join, which:
1. Registers the device in Entra ID
2. Configures Windows to accept Entra ID credentials for interactive (RDP) login

**Prerequisite — system-assigned managed identity:** Secure VM Join calls the IMDS token endpoint (`http://169.254.169.254/metadata/identity/oauth2/token`) to resolve the tenant ID. This endpoint only responds when a managed identity is assigned. Without it the extension fails with `DsrCmdAzureHelper::GetTenantId failed 0x801c002d` regardless of connectivity.

```powershell
$aadJson = '{"location":"centralus","properties":{"publisher":"Microsoft.Azure.ActiveDirectory","type":"AADLoginForWindows","typeHandlerVersion":"2.0","autoUpgradeMinorVersion":true,"settings":{"mdmId":""}}}'
$aadJson | Out-File "$env:TEMP\aad-ext.json" -Encoding utf8 -NoNewline

az rest --method PUT `
  --url "https://management.azure.com/subscriptions/00f08d69-e072-45e3-841a-bcec85e47411/resourceGroups/dwp-lab-rg/providers/Microsoft.Compute/virtualMachines/avd-fin-sh01/extensions/AADLoginForWindows?api-version=2023-03-01" `
  --body "@$env:TEMP\aad-ext.json"
```

**Verification (inside VM via run-command):**
```powershell
az vm run-command invoke --resource-group "dwp-lab-rg" --name "avd-fin-sh01" `
  --command-id "RunPowerShellScript" `
  --scripts "dsregcmd /status | Select-String 'AzureAdJoined|TenantId'" `
  --query "value[0].message" -o tsv
```
Expected output:
```
AzureAdJoined : YES
TenantId      : fa8443c6-5a39-4df5-a018-9c876455adf9
```

---

## Step 9 — Assign roles to the end user

Two roles are required for `p21@zippyops.in`:

| Role | Scope | Grants |
|---|---|---|
| **Desktop Virtualization User** | POOL-FIN-01-DAG (app group) | Access to the published desktop via Remote Desktop client / web |
| **Virtual Machine User Login** | avd-fin-sh01 (VM) | Entra ID authentication for direct RDP to the VM |

```powershell
$userOid = az ad user show --id "p21@zippyops.in" --query "id" -o tsv
$sub = "00f08d69-e072-45e3-841a-bcec85e47411"
$rg  = "dwp-lab-rg"

# AVD client access
az role assignment create `
  --assignee $userOid --role "Desktop Virtualization User" `
  --scope "/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.DesktopVirtualization/applicationGroups/POOL-FIN-01-DAG"

# Direct RDP via Entra ID
az role assignment create `
  --assignee $userOid --role "Virtual Machine User Login" `
  --scope "/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.Compute/virtualMachines/avd-fin-sh01"
```

---

## Final verification — session host status

```powershell
az rest --method GET `
  --url "https://management.azure.com/subscriptions/00f08d69-e072-45e3-841a-bcec85e47411/resourceGroups/dwp-lab-rg/providers/Microsoft.DesktopVirtualization/hostPools/POOL-FIN-01/sessionHosts/avd-fin-sh01?api-version=2022-09-09" `
  --query "{status:properties.status,lastHeartbeat:properties.lastHeartBeat,agentVersion:properties.agentVersion,osVersion:properties.osVersion}" -o table

az rest --method GET `
  --url "https://management.azure.com/subscriptions/00f08d69-e072-45e3-841a-bcec85e47411/resourceGroups/dwp-lab-rg/providers/Microsoft.DesktopVirtualization/hostPools/POOL-FIN-01/sessionHosts/avd-fin-sh01?api-version=2022-09-09" `
  --query "properties.sessionHostHealthCheckResults[].{Check:healthCheckName,Result:healthCheckResult}" -o table
```

**Confirmed output:**
```
Status     LastHeartbeat            AgentVersion    OsVersion
---------  -----------------------  --------------  ---------------
Available  2026-08-13T06:41:42.16Z  1.0.15008.300   10.0.26100.9168
```

```
Check                       Result
--------------------------  --------------------
DomainJoinedCheck           HealthCheckSucceeded
DomainTrustCheck            HealthCheckSucceeded
SxSStackListenerCheck       HealthCheckSucceeded
MetaDataServiceCheck        HealthCheckSucceeded
AppAttachHealthCheck        HealthCheckSucceeded
TURNRelayAccessHealthCheck  HealthCheckSucceeded
AADJoinedHealthCheck        HealthCheckSucceeded
```

All 7 health checks green. Session host status: **Available**.

---

## Issues encountered and root causes

### Issue 1 — `az desktopvirtualization` extension hung on install prompt
**Symptom:** `az desktopvirtualization hostpool create` moved to background and was killed by a "Terminate batch job" prompt because `az.cmd` (a Windows batch wrapper) cannot receive interactive input in this terminal environment.  
**Resolution:** Bypassed the extension entirely. All AVD control-plane resources (host pool, app group, workspace, registration token) were created and queried using `az rest` with the ARM API directly. This is fully supported and produces identical results.

---

### Issue 2 — DSC extension failed: "Unable to connect to the remote server"
**Symptom:** DSC extension failed after 17 download attempts against `wvdportalstorageblob.blob.core.windows.net`.  
**Root cause:** **Azure default outbound SNAT was retired on 30 September 2025.** VMs created after that date with no public IP and no NAT gateway have zero outbound internet connectivity. The VM was created with `--public-ip-address ""` (correct for AVD) but without any outbound path.  
**Resolution:** Created a Standard SKU NAT gateway (`avd-natgw`) with a static public IP, associated it with `avd-subnet`, then deleted and resubmitted the DSC extension. The 96 MB agent package downloaded successfully in ~27 seconds.

---

### Issue 3 — AADLoginForWindows failed: `GetTenantId failed 0x801c002d`
**Symptom:** `AADLoginForWindows` v2.0 (Secure VM Join) failed immediately with `AzureSecureVMJoinOperation: DsrCmdAzureHelper::GetTenantId failed 0x801c002d` (DSREG_E_DSREGDISCO_FAILED).  
**Root cause:** Secure VM Join resolves the tenant ID by requesting an IMDS identity token from `http://169.254.169.254/metadata/identity/oauth2/token`. This endpoint only works when the VM has a **system-assigned managed identity**. The VM was created without one, causing the token request to fail and leaving the extension unable to determine which Entra ID tenant to join.  
**Diagnosis steps:**
- Confirmed TCP 443 reachability to `enterpriseregistration.windows.net` ✓
- Confirmed IMDS at `169.254.169.254` returned subscription ID ✓  
- Confirmed device was NOT in Entra ID via `dsregcmd /status` and Graph API query
- Identified no managed identity on the VM via `az vm show`  

**Resolution:** Assigned system-assigned managed identity (`az vm identity assign --identities "[system]"`). Removed and resubmitted `AADLoginForWindows`. Extension succeeded, `dsregcmd /status` confirmed `AzureAdJoined: YES`.

> **Design note for repeat deployments:** The deployment script [Deploy-AVD-EntraIDOnly.ps1](Deploy-AVD-EntraIDOnly.ps1) assigns the managed identity immediately after `az vm create`, before any extension is installed, eliminating this failure.

---

## Files in this folder

| File | Purpose |
|---|---|
| `AVD-Provisioning-RunBook.md` | This document — step-by-step run book with commands, verifications, and issue log |
| `Deploy-AVD-EntraIDOnly.ps1` | Parameterised PowerShell script that automates all 9 steps end-to-end |
