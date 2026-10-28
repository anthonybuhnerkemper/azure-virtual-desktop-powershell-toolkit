#Requires -Version 7.4
#Requires -Modules Az.Accounts, Az.DesktopVirtualization, Az.Compute
<#
.SYNOPSIS
    Safely restarts Azure Virtual Desktop session hosts: drain, check for sessions, restart, undrain.
.DESCRIPTION
    For each host: turns drain mode on, skips the host if it still has user sessions (unless -Force),
    restarts the VM, waits until the host reports Available again, then turns drain mode back off.
    If a host does not come back within the timeout it is left in drain mode so users are not sent
    to a broken host. Supports -WhatIf / -Confirm and writes a change log CSV.
    Tip: run Send-AvdUserMessage.ps1 first, then this script after users have signed out.
.PARAMETER ResourceGroupName
    Resource group of the host pool.
.PARAMETER HostPoolName
    Host pool name.
.PARAMETER SessionHostName
    One or more session host names to restart.
.PARAMETER Force
    Restart even if users are still signed in. Their unsaved work is lost.
.PARAMETER TimeoutMinutes
    How long to wait for a host to come back. Default 15.
.PARAMETER OutputFolder
    Folder for the change log. Defaults to ./output.
.EXAMPLE
    ./Restart-AvdSessionHost.ps1 -ResourceGroupName rg-avd-prod -HostPoolName hp-contoso-pooled -SessionHostName avd-contoso-0.contoso.com -WhatIf
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][string]$ResourceGroupName,
    [Parameter(Mandatory)][string]$HostPoolName,
    [Parameter(Mandatory)][string[]]$SessionHostName,
    [switch]$Force,
    [ValidateRange(5, 60)][int]$TimeoutMinutes = 15,
    [string]$OutputFolder = (Join-Path (Get-Location) 'output')
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { throw 'Not connected. Run Connect-M365Admin -Service Azure first.' }
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
$pool = @{ ResourceGroupName = $ResourceGroupName; HostPoolName = $HostPoolName }

$log = foreach ($name in $SessionHostName) {
    $result = 'Skipped'
    $h = Get-AzWvdSessionHost @pool -Name $name
    if ($PSCmdlet.ShouldProcess($name, 'Drain, restart VM and return to service')) {
        Update-AzWvdSessionHost @pool -Name $name -AllowNewSession:$false | Out-Null
        $h = Get-AzWvdSessionHost @pool -Name $name
        if ($h.Session -gt 0 -and -not $Force) {
            $result = "Left drained: $($h.Session) session(s) still open"
        }
        else {
            Restart-AzVM -Id $h.ResourceId | Out-Null
            $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
            Start-Sleep -Seconds 60
            do {
                $status = (Get-AzWvdSessionHost @pool -Name $name).Status
                if ($status -ne 'Available') { Start-Sleep -Seconds 30 }
            } while ($status -ne 'Available' -and (Get-Date) -lt $deadline)
            if ($status -eq 'Available') {
                Update-AzWvdSessionHost @pool -Name $name -AllowNewSession:$true | Out-Null
                $result = 'Restarted and back in service'
            }
            else { $result = "Restarted but status is $status; left in drain mode" }
        }
    }
    Write-Information "$name`: $result" -InformationAction Continue
    [pscustomobject]@{ TimeUtc = (Get-Date).ToUniversalTime(); SessionHost = $name; Result = $result }
}
$log | Export-Csv (Join-Path $OutputFolder "AvdHostRestart-$(Get-Date -Format 'yyyyMMdd-HHmm').csv") -NoTypeInformation
