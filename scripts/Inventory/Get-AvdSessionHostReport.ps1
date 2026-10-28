#Requires -Version 7.4
#Requires -Modules Az.Accounts, Az.DesktopVirtualization
<#
.SYNOPSIS
    Reports the health of every session host in one or all Azure Virtual Desktop host pools.
.DESCRIPTION
    Read-only. For each session host shows status, drain mode (AllowNewSession), current sessions,
    agent version, last heartbeat and any failed health checks. Flags hosts that are unavailable,
    stuck in drain mode, or have not sent a heartbeat recently. Exports CSV.
.PARAMETER ResourceGroupName
    Resource group of the host pool. Required with -HostPoolName.
.PARAMETER HostPoolName
    Optional. One host pool. Without it, every host pool in the subscription is checked.
.PARAMETER HeartbeatMinutes
    A host with no heartbeat newer than this is flagged. Default 30.
.PARAMETER OutputFolder
    Folder for CSV output. Defaults to ./output.
.EXAMPLE
    ./Get-AvdSessionHostReport.ps1
.EXAMPLE
    ./Get-AvdSessionHostReport.ps1 -ResourceGroupName rg-avd-prod -HostPoolName hp-contoso-pooled
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName,
    [string]$HostPoolName,
    [ValidateRange(5, 1440)][int]$HeartbeatMinutes = 30,
    [string]$OutputFolder = (Join-Path (Get-Location) 'output')
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { throw 'Not connected. Run Connect-M365Admin -Service Azure first.' }
if ($HostPoolName -and -not $ResourceGroupName) { throw 'Provide -ResourceGroupName with -HostPoolName.' }
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

$pools = if ($HostPoolName) { @(Get-AzWvdHostPool -ResourceGroupName $ResourceGroupName -Name $HostPoolName) } else { @(Get-AzWvdHostPool) }
$cutoff = (Get-Date).ToUniversalTime().AddMinutes(-$HeartbeatMinutes)

$rows = foreach ($pool in $pools) {
    $rg = ($pool.Id -split '/')[4]
    foreach ($h in @(Get-AzWvdSessionHost -ResourceGroupName $rg -HostPoolName $pool.Name)) {
        $failed = @($h.SessionHostHealthCheckResult | Where-Object { $_.HealthCheckResult -and $_.HealthCheckResult -ne 'HealthCheckSucceeded' })
        $beat = if ($h.LastHeartBeat) { ([datetime]$h.LastHeartBeat).ToUniversalTime() } else { $null }
        $issues = @()
        if ($h.Status -ne 'Available') { $issues += "Status $($h.Status)" }
        if (-not $h.AllowNewSession) { $issues += 'Drain mode on' }
        if (-not $beat -or $beat -lt $cutoff) { $issues += 'No recent heartbeat' }
        if ($failed) { $issues += "Failed checks: $($failed.HealthCheckName -join ', ')" }
        [pscustomobject]@{
            HostPool        = $pool.Name
            SessionHost     = ($h.Name -split '/')[-1]
            Status          = $h.Status
            AllowNewSession = $h.AllowNewSession
            Sessions        = $h.Session
            MaxSessions     = $pool.MaxSessionLimit
            AgentVersion    = $h.AgentVersion
            UpdateState     = $h.UpdateState
            LastHeartbeatUtc = $beat
            AssignedUser    = $h.AssignedUser
            Issues          = $issues -join '; '
        }
    }
}

$file = Join-Path $OutputFolder "AvdSessionHosts-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"
$rows | Export-Csv $file -NoTypeInformation
$rows | Format-Table HostPool, SessionHost, Status, AllowNewSession, Sessions, AgentVersion, Issues -AutoSize -Wrap
$bad = @($rows | Where-Object Issues)
Write-Information "Session hosts: $(@($rows).Count). Needing attention: $($bad.Count). CSV: $file" -InformationAction Continue
