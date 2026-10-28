# 04 - A safe maintenance window

The goal is to patch or restart a host without kicking anyone off by surprise.

## 1. Drain the host
```powershell
./scripts/Maintenance/Set-AvdDrainMode.ps1 -ResourceGroupName rg-avd-prod -HostPoolName hp-contoso-pooled -SessionHostName avd-contoso-0.contoso.com -Mode On
```
Current users keep working. New sign-ins go to other hosts.

## 2. Warn the users still on it
```powershell
./scripts/Sessions/Send-AvdUserMessage.ps1 -ResourceGroupName rg-avd-prod -HostPoolName hp-contoso-pooled -SessionHostName avd-contoso-0.contoso.com -Title 'Maintenance' -Message 'Please sign out by 6 PM.'
```

## 3. Restart when it is empty
```powershell
./scripts/Maintenance/Restart-AvdSessionHost.ps1 -ResourceGroupName rg-avd-prod -HostPoolName hp-contoso-pooled -SessionHostName avd-contoso-0.contoso.com -WhatIf
```
The script will not restart a host that still has sessions unless you add `-Force`. After the restart it waits for the host to report `Available`, then turns drain mode off. If the host does not come back, it stays drained so nobody lands on a broken desktop.

For several hosts, keep the list in a CSV like `samples/maintenance-hosts.sample.csv` and do them in small batches so the pool keeps enough capacity:
```powershell
$batch = Import-Csv ./samples/maintenance-hosts.sample.csv | Where-Object Batch -eq 1
./scripts/Maintenance/Restart-AvdSessionHost.ps1 -ResourceGroupName rg-avd-prod -HostPoolName hp-contoso-pooled -SessionHostName $batch.SessionHost
```

## 4. Check
Run `Get-AvdSessionHostReport.ps1` again. Every host should be `Available` with drain mode off.
