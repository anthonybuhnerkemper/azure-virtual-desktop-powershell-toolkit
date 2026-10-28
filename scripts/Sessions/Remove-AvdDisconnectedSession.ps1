#Requires -Version 7.4
#Requires -Modules Az.Accounts, Az.DesktopVirtualization
<#
.SYNOPSIS
    Signs out disconnected Azure Virtual Desktop sessions that are older than a set number of hours.
.DESCRIPTION
    Disconnected sessions hold memory, FSLogix profile locks and a slot on the host. This script
    finds sessions in the Disconnected state whose creation time is older than -OlderThanHours and
    signs them out (Remove-AzWvdUserSession). The API does not expose the time a session was
    disconnected, so creation time is used as a safe, conservative proxy. Unsaved work in those
    sessions is lost, so the default ConfirmImpact is High. Supports -WhatIf / -Confirm and writes
    a change log CSV.
.PARAMETER ResourceGroupName
    Resource group of the host pool.
.PARAMETER HostPoolName
    Host pool name.
.PARAMETER OlderThanHours
    Only sessions created more than this many hours ago. Default 24.
.PARAMETER ExcludeUser
    UPNs to never sign out (for example a kiosk or service account).
.PARAMETER OutputFolder
    Folder for the change log. Defaults to ./output.
.EXAMPLE
    ./Remove-AvdDisconnectedSession.ps1 -ResourceGroupName rg-avd-prod -HostPoolName hp-contoso-pooled -WhatIf
.EXAMPLE
    ./Remove-AvdDisconnectedSession.ps1 -ResourceGroupName rg-avd-prod -HostPoolName hp-contoso-pooled -OlderThanHours 12 -Confirm:$false
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][string]$ResourceGroupName,
    [Parameter(Mandatory)][string]$HostPoolName,
    [ValidateRange(1, 720)][int]$OlderThanHours = 24,
    [string[]]$ExcludeUser = @(),
    [string]$OutputFolder = (Join-Path (Get-Location) 'output')
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { throw 'Not connected. Run Connect-M365Admin -Service Azure first.' }
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

$cutoff = (Get-Date).ToUniversalTime().AddHours(-$OlderThanHours)
$targets = @(Get-AzWvdUserSession -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName | Where-Object {
        $_.SessionState -eq 'Disconnected' -and $_.CreateTime -and ([datetime]$_.CreateTime).ToUniversalTime() -lt $cutoff -and
        $_.UserPrincipalName -notin $ExcludeUser
    })

$log = foreach ($s in $targets) {
    $parts = $s.Name -split '/'
    $result = 'Skipped'
    if ($PSCmdlet.ShouldProcess("$($s.UserPrincipalName) on $($parts[1])", 'Sign out disconnected session')) {
        try {
            Remove-AzWvdUserSession -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName `
                -SessionHostName $parts[1] -Id $parts[2]
            $result = 'SignedOut'
        }
        catch { $result = "Failed: $($_.Exception.Message)" }
    }
    [pscustomobject]@{ TimeUtc = (Get-Date).ToUniversalTime(); User = $s.UserPrincipalName; SessionHost = $parts[1]; SessionId = $parts[2]; Result = $result }
}

if ($log) {
    $file = Join-Path $OutputFolder "AvdSessionSignOut-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"
    $log | Export-Csv $file -NoTypeInformation
    $log | Format-Table -AutoSize
}
Write-Information "Disconnected sessions older than $OlderThanHours h: $($targets.Count)." -InformationAction Continue
