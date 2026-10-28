# 02 - Inventory and session host health

## 1. What do we have?
```powershell
./scripts/Inventory/Get-AvdEnvironmentReport.ps1
```
You get `AvdHostPools-*.csv` and `AvdAppGroups-*.csv`. Look for:
- **Application groups not published in a workspace.** Users assigned to them see nothing in the client.
- **Pooled pools with a high MaxSessionLimit.** Size it to what the VM can really handle.
- **No validation pool.** A small pool with `ValidationPool = True` gets AVD agent updates first, so you see problems before production does.

## 2. Are the hosts healthy?
```powershell
./scripts/Inventory/Get-AvdSessionHostReport.ps1 -HeartbeatMinutes 30
```
The `Issues` column flags hosts that are not `Available`, left in drain mode, missing heartbeats, or failing health checks (for example FSLogix, domain join or the SxS stack).

Common causes:
- **Unavailable / NoHeartbeat:** the VM is stopped (normal with a scaling plan) or the RDAgent service is stuck. Check the VM power state first.
- **Drain mode left on:** someone patched the host and forgot to turn it back. See doc 04.
- **UpgradeFailed:** the agent update failed. Restart the host, then reinstall the agent if it stays failed.

Run the report every morning and you will catch most user complaints before the help desk does.
