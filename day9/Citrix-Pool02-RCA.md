# Root Cause Analysis
## Citrix VDI Session Launch Failure — FinBridge-VDI-Pool-02
### Incident Date: 2026-08-13 | Classification: P2 — Partial Service Loss

---

## 1. Executive Summary

22 of 30 users on FinBridge-VDI-Pool-02 were unable to launch VDI sessions from approximately 00:15 on 2026-08-13. The failure was caused by the Citrix Broker Service stopping on Delivery Controller dc-vdi-02.finbridge.local following a Windows Update installation. The service was not configured to auto-restart and was not monitored. The pending reboot state meant the failure persisted undetected until users attempted to connect at the start of business. FinBridge-VDI-Pool-01 was unaffected as it is served by a separate Delivery Controller (dc-vdi-01) which did not receive the update.

---

## 2. Incident Timeline

| Time | Event |
|---|---|
| Yesterday 23:40 | Citrix Broker Service on dc-vdi-02 last confirmed running |
| Today 00:15 | Windows Update installed on dc-vdi-02; reboot-required flag set |
| 00:15 – 06:15 | Broker Service not running; no alert raised; no one online to detect |
| 06:15:22 | VDI-P02-014 attempts re-registration — `connection refused` on port 80 |
| 06:16:01 | VDI-P02-017 attempts re-registration — `connection refused` on port 80 |
| 06:15 – 08:58 | Further 20 machines attempt and fail re-registration (inferred) |
| 08:58:03 | First recorded user session launch attempt (jsmith) — Pool-02 |
| 08:58:04 | Broker queries Pool-02 for available machines |
| 08:58:34 | Broker timeout (30,000 ms) — error 1030 raised |
| 08:58:34 | Session launch fails: `No machines available in the desktop group` |
| 08:58+ | 22 users unable to access Pool-02 desktop |
| (Remediation) | Citrix Broker Service restarted on dc-vdi-02 |
| (Remediation) | 22 machines re-register with broker |
| (Remediation) | Session launch validated — incident resolved |
| (Pending) | Controlled reboot of dc-vdi-02 to clear reboot-required flag |

---

## 3. Supporting Evidence

### 3.1 Session Broker Log

```
[08:58:03] Session launch requested: user jsmith, Pool-02
[08:58:04] Broker: Querying available machines in Pool-02
[08:58:34] Broker: Timeout waiting for machine registration response (30000ms exceeded)
[08:58:34] Session launch FAILED: error 1030
            'No machines available in the desktop group'
```

### 3.2 Machine Catalog Status at Time of Incident

| Pool | Provisioned | Registered | Unregistered |
|---|---|---|---|
| Pool-02 | 25 | 3 | 22 |
| Pool-01 | 20 | 19 | 1 |

### 3.3 Unregistered Machine Errors (Pool-02)

```
VDI-P02-014 [06:15:22]: Unable to contact Delivery Controller
  dc-vdi-02.finbridge.local:80 — connection refused

VDI-P02-017 [06:16:01]: Unable to contact Delivery Controller
  dc-vdi-02.finbridge.local:80 — connection refused
```

Port 80 is the Citrix Broker Service HTTP registration endpoint. `Connection refused` confirms no process is listening — consistent with the service being STOPPED.

### 3.4 Delivery Controller State

```
dc-vdi-02:
  CitrixBrokerService : STOPPED
  Last running        : yesterday 23:40
  Windows Update      : today 00:15 (reboot required, host not rebooted)

dc-vdi-01:
  CitrixBrokerService : RUNNING
  Uptime              : 14 days
```

### 3.5 Isolation Evidence

| Factor | dc-vdi-02 (Pool-02) | dc-vdi-01 (Pool-01) |
|---|---|---|
| Broker Service | STOPPED | RUNNING |
| Windows Update today | Yes | Not recorded |
| Pending reboot | Yes | No |
| Users affected | 22 | 0 |

Same site, same network, same Citrix site version. The only differentiating factor is the state of the respective Delivery Controller.

---

## 4. Root Cause Statement

**Windows Update installed on dc-vdi-02 at 00:15 stopped (or caused the stop of) the Citrix Broker Service. The service was not configured to auto-restart on failure, and no monitoring alert was in place to detect a STOPPED state. The service remained stopped for approximately 8.5 hours. All Pool-02 VDI machines whose broker registration heartbeat expired during this window were unable to re-register because port 80 (the broker HTTP endpoint) was refusing connections. At start of business, 22 of 25 machines were unregistered, leaving only 3 machines available — insufficient to serve 30 users — resulting in error 1030 for all new session requests.**

---

## 5. Five-Why Analysis

```
WHY 1: Why were users unable to launch VDI sessions?
  → The broker reported error 1030: no machines available in the desktop group.

WHY 2: Why were no machines available?
  → 22 of 25 machines in Pool-02 were in Unregistered state.

WHY 3: Why were the machines unregistered?
  → They could not contact the Delivery Controller (dc-vdi-02:80 — connection refused).
    The Citrix Broker Service on dc-vdi-02 was STOPPED.

WHY 4: Why was the Citrix Broker Service stopped?
  → Windows Update ran at 00:15 and stopped the service (either directly as part
    of the update process, or the update placed the host in a pending-reboot state
    that caused the service to fail). The service did not auto-restart.

WHY 5: Why was the stopped service not detected and restarted?
  → No monitoring alert was configured on CitrixBrokerService state.
    No service recovery action was set (auto-restart on failure).
    The failure occurred out of hours (00:15) with no on-call detection mechanism.
```

---

## 6. Contributing Factors

| Factor | Detail |
|---|---|
| No service auto-restart | CitrixBrokerService had no failure recovery action configured |
| No out-of-hours monitoring | No alert raised when service stopped at ~00:15 |
| Uncontrolled update timing | Windows Update ran during a period with no engineer coverage |
| Reboot not applied | Reboot-required flag left set, placing host in an indeterminate post-update state |
| Single DC for Pool-02 | No redundant Delivery Controller meant Pool-02 had no failover path |

---

## 7. Remediation Steps (In Order)

1. **Start CitrixBrokerService on dc-vdi-02**
   ```powershell
   Start-Service "CitrixBrokerService"
   Get-Service "CitrixBrokerService" | Select-Object Name, Status
   ```

2. **Confirm port 80 is listening**
   ```cmd
   netstat -an | findstr ":80 "
   ```

3. **Monitor Pool-02 machine re-registration** (allow up to 5 min)
   ```powershell
   Get-BrokerMachine -DesktopGroupName "FinBridge-VDI-Pool-02" |
     Group-Object RegistrationState | Select-Object Name, Count
   ```

4. **Validate session launch** — test as an affected user

5. **Schedule controlled reboot of dc-vdi-02** during next maintenance window to clear reboot-required flag

---

## 8. Verification of Resolution

| Check | Expected Result |
|---|---|
| `Get-Service CitrixBrokerService` on dc-vdi-02 | Status = Running |
| `netstat -an \| findstr ":80 "` | TCP 0.0.0.0:80 LISTENING |
| `Get-BrokerMachine` registration count | Registered = 25, Unregistered = 0 |
| Session launch test as affected user | Desktop loads, no error 1030 |

---

## 9. Preventive Actions

### Immediate (within 24 hours)

| Action | Command / Steps |
|---|---|
| **Configure auto-restart on both DCs** | `sc failure "CitrixBrokerService" reset=86400 actions=restart/60000/restart/60000/restart/60000` |
| **Set StartType to Automatic (Delayed)** | `Set-Service CitrixBrokerService -StartupType AutomaticDelayedStart` |
| **Apply pending reboot on dc-vdi-02** | Reboot during next approved maintenance window |

### Short-term (within 1 week)

| Action | Detail |
|---|---|
| **Service monitoring alert** | Configure alert within 2 minutes of CitrixBrokerService entering STOPPED state on any Delivery Controller |
| **Out-of-hours on-call procedure** | Ensure infrastructure alerts page an on-call engineer 24/7 |
| **Windows Update scheduling** | Move update window to Saturday 02:00–04:00 with mandatory reboot at completion; exclude Delivery Controllers from auto-update during weekdays |

### Medium-term (within 1 month)

| Action | Detail |
|---|---|
| **Second Delivery Controller for Pool-02** | Deploy dc-vdi-03 as a redundant DC for Pool-02 so machines can fail over if one broker stops |
| **Citrix Director dashboard review** | Confirm Director health alarms are enabled for broker service state |
| **Change management gate for DC patching** | Require a change ticket and test plan before applying updates to any Delivery Controller |

---

## 10. Lessons Learned

| Lesson | Application |
|---|---|
| A single stopped service caused 22 users to lose access for 8+ hours | Critical services must have auto-restart and active monitoring |
| Out-of-hours failures go undetected without alerting | Monitoring coverage must extend to all hours for production services |
| Uncontrolled Windows Update on infrastructure components is high risk | Delivery Controllers must be in a separate, controlled update ring |
| Single point of failure on dc-vdi-02 for Pool-02 | Production pools require redundant Delivery Controllers |

---

## 11. Document Information

| Field | Detail |
|---|---|
| Prepared by | traininguser23@zippyops.in |
| Date | 2026-08-13 |
| Related document | `Citrix-Pool02-Session-Failure-Analysis.md` |
| Status | Draft — pending sign-off after resolution confirmed |
