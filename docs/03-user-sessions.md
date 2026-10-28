# 03 - Working with user sessions

## 1. Find a user
```powershell
./scripts/Sessions/Get-AvdUserSessionReport.ps1 -ResourceGroupName rg-avd-prod -HostPoolName hp-contoso-pooled -UserPrincipalName adele.vance@contoso.com
```
Shows which host the user is on, whether the session is active or disconnected, and when it started. That is usually the first question on a "my desktop is slow" ticket.

## 2. Message users
```powershell
./scripts/Sessions/Send-AvdUserMessage.ps1 -ResourceGroupName rg-avd-prod -HostPoolName hp-contoso-pooled `
    -SessionHostName avd-contoso-0.contoso.com -Title 'Maintenance' -Message 'Please save your work. This desktop restarts at 6 PM.' -WhatIf
```
Only active sessions get the message. Leave out `-SessionHostName` to message the whole pool.

## 3. Sign out stale disconnected sessions
Disconnected sessions keep memory in use and can hold an FSLogix profile lock, which stops the user from signing in somewhere else.
```powershell
./scripts/Sessions/Remove-AvdDisconnectedSession.ps1 -ResourceGroupName rg-avd-prod -HostPoolName hp-contoso-pooled -OlderThanHours 24 -WhatIf
```
The API does not say when a session was disconnected, so the script uses the session start time. A session that started yesterday and is now disconnected is a safe target. Unsaved work is lost, so tell users about the policy first. A Group Policy or Intune session time limit for disconnected sessions is the long-term fix; this script covers the gaps.
