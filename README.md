# Azure Virtual Desktop PowerShell Toolkit

A practical toolkit and step-by-step guide for **Azure Virtual Desktop (AVD)** with **PowerShell 7** and the **Az.DesktopVirtualization** module.

It covers environment inventory, session host health, user session lookups, messaging users before maintenance, signing out stale disconnected sessions, drain mode, safe host restarts, application group access reviews and scaling plan coverage. Every script has comment-based help (`Get-Help ./script.ps1 -Full`), reports export to CSV, and every change script supports `-WhatIf` / `-Confirm`. Azure authentication uses **certificates** (app-only) or **interactive** sign-in via the same `Connect-M365Admin` pattern as [graph-powershell7-admin-toolkit](https://github.com/anthonybuhnerkemper/graph-powershell7-admin-toolkit). No secrets are stored in the repo.

> ⚠️ **Disclaimer:** Test everything in a non-production subscription or a validation host pool first. Examples use `contoso.com`, resource groups like `rg-avd-prod`, host pools like `hp-contoso-pooled`, session hosts like `avd-contoso-0.contoso.com`, and placeholder GUIDs (`00000000-0000-0000-0000-000000000000`). Review each script before running it in your environment.

## Prerequisites

| Requirement | Version / notes |
|---|---|
| PowerShell | 7.4 or later (`pwsh`), Windows, macOS or Linux |
| Az.Accounts | 3.x or later |
| Az.DesktopVirtualization | 4.x or later |
| Az.Compute | Only for `Restart-AvdSessionHost` |
| Az.Resources | Only for `Get-AvdAppGroupAssignmentReport` |
| Rights | **Desktop Virtualization Reader** for reports; **Desktop Virtualization Session Host Operator** / **User Session Operator** for changes; **Virtual Machine Contributor** to restart VMs |

```powershell
Install-Module Az.Accounts, Az.DesktopVirtualization, Az.Compute, Az.Resources -Scope CurrentUser
```

## Quick start

```powershell
git clone https://github.com/anthonybuhnerkemper/azure-virtual-desktop-powershell-toolkit.git
cd azure-virtual-desktop-powershell-toolkit

. ./scripts/Connect/Connect-M365Admin.ps1
Connect-M365Admin -Service Azure -Interactive -SubscriptionId 00000000-0000-0000-0000-000000000000

# Reports (CSV files land in ./output)
./scripts/Inventory/Get-AvdEnvironmentReport.ps1
./scripts/Inventory/Get-AvdSessionHostReport.ps1
./scripts/Sessions/Get-AvdUserSessionReport.ps1 -ResourceGroupName rg-avd-prod -HostPoolName hp-contoso-pooled
./scripts/Access/Get-AvdAppGroupAssignmentReport.ps1
./scripts/Cost/Get-AvdScalingPlanReport.ps1

# Preview a change before applying it
./scripts/Maintenance/Set-AvdDrainMode.ps1 -ResourceGroupName rg-avd-prod -HostPoolName hp-contoso-pooled -SessionHostName avd-contoso-0.contoso.com -Mode On -WhatIf

. ./scripts/Connect/Disconnect-M365Admin.ps1
Disconnect-M365Admin
```

## Repo map

```text
.github/workflows/pssa.yml  PSScriptAnalyzer CI on push and PR
docs/
  01-prerequisites-and-connect.md
  02-inventory-and-host-health.md
  03-user-sessions.md
  04-maintenance-window.md
  05-access-and-cost.md
samples/          maintenance-hosts.sample.csv (fake host names)
scripts/
  Connect/        Connect-M365Admin.ps1, Disconnect-M365Admin.ps1
  Inventory/      Get-AvdEnvironmentReport, Get-AvdSessionHostReport
  Sessions/       Get-AvdUserSessionReport, Send-AvdUserMessage, Remove-AvdDisconnectedSession
  Maintenance/    Set-AvdDrainMode, Restart-AvdSessionHost
  Access/         Get-AvdAppGroupAssignmentReport
  Cost/           Get-AvdScalingPlanReport
```

## Scripts and permissions

| Script | Needs | Changes? |
|---|---|---|
| Get-AvdEnvironmentReport | Desktop Virtualization Reader | No |
| Get-AvdSessionHostReport | Desktop Virtualization Reader | No |
| Get-AvdUserSessionReport | Desktop Virtualization Reader | No |
| Send-AvdUserMessage | Desktop Virtualization User Session Operator | Yes (`-WhatIf`) |
| Remove-AvdDisconnectedSession | Desktop Virtualization User Session Operator | Yes (`-WhatIf`) |
| Set-AvdDrainMode | Desktop Virtualization Session Host Operator | Yes (`-WhatIf`) |
| Restart-AvdSessionHost | Session Host Operator + Virtual Machine Contributor | Yes (`-WhatIf`) |
| Get-AvdAppGroupAssignmentReport | Reader on the application groups | No |
| Get-AvdScalingPlanReport | Desktop Virtualization Reader | No |

## Related

- [intune-powershell-toolkit](https://github.com/anthonybuhnerkemper/intune-powershell-toolkit): device inventory and compliance for the session host images you manage with Intune
- [entra-id-powershell-toolkit](https://github.com/anthonybuhnerkemper/entra-id-powershell-toolkit): groups and user lifecycle behind your AVD access
- [citrix-powershell-toolkit](https://github.com/anthonybuhnerkemper/citrix-powershell-toolkit): the same kind of checks for Citrix Virtual Apps and Desktops

## License

[MIT](LICENSE) © 2026 Anthony Buhnerkemper
