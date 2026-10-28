# 01 - Prerequisites and connecting

## 1. Install the modules
```powershell
Install-Module Az.Accounts, Az.DesktopVirtualization -Scope CurrentUser
# Only if you use the restart or access scripts
Install-Module Az.Compute, Az.Resources -Scope CurrentUser
```
All scripts run in PowerShell 7.4 on Windows, macOS or Linux. Nothing needs to run on the session hosts themselves.

## 2. Permissions
Use the built-in AVD roles and give the smallest one that does the job, scoped to the resource group that holds your host pools.

| Task | Role |
|---|---|
| All reports | Desktop Virtualization Reader |
| Message users, sign out sessions | Desktop Virtualization User Session Operator |
| Drain mode | Desktop Virtualization Session Host Operator |
| Restart a host VM | Virtual Machine Contributor on the VMs |
| Read app group assignments | Reader (or User Access Administrator read) on the application groups |

## 3. Connect to Azure
```powershell
. ./scripts/Connect/Connect-M365Admin.ps1
Connect-M365Admin -Service Azure -Interactive -SubscriptionId 00000000-0000-0000-0000-000000000000
```
For a scheduled task or an Azure Automation runbook, use a service principal with a certificate:
```powershell
$env:M365_TENANT_ID       = '00000000-0000-0000-0000-000000000000'
$env:M365_CLIENT_ID       = '00000000-0000-0000-0000-000000000000'
$env:M365_CERT_THUMBPRINT = '0000000000000000000000000000000000000000'
$env:AZ_SUBSCRIPTION_ID   = '00000000-0000-0000-0000-000000000000'
Connect-M365Admin -Service Azure
```
Check you are in the right subscription with `Get-AzContext` before running a change script. When you are done, run `Disconnect-M365Admin`.
