# 05 - Access reviews and cost

## 1. Who can see what?
```powershell
./scripts/Access/Get-AvdAppGroupAssignmentReport.ps1
```
Users get a desktop or RemoteApp through the **Desktop Virtualization User** role on an application group. The report flags:
- **Direct user assignments.** Move them to an Entra ID group so joiners and leavers are handled in one place.
- **Application groups with no assignments.** Either remove them or assign the right group.

Do this review once a quarter, or before an audit.

## 2. Are we paying for idle hosts?
```powershell
./scripts/Cost/Get-AvdScalingPlanReport.ps1
```
You get every scaling plan with its schedule times, and a second CSV of host pools with **no enabled scaling plan**. Those pools run every VM all day and all night.

Things to check:
- The plan time zone matches where your users are.
- Off-peak starts soon after the workday ends.
- Ramp-down force logoff is set the way you expect, and users know about it.
- Start VM on Connect is on for the pool (see `Get-AvdEnvironmentReport.ps1`), so a user can still sign in after hours.
