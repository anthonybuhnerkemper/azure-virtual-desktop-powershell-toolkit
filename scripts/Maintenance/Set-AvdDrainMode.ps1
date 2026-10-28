#Requires -Version 7.4
#Requires -Modules Az.Accounts, Az.DesktopVirtualization
<#
.SYNOPSIS
    Turns drain mode on or off for one or more Azure Virtual Desktop session hosts.
.DESCRIPTION
    Drain mode (AllowNewSession = false) stops new users from landing on a host while existing
    sessions keep working. Use it before patching, resizing or reimaging a host. Pass session host
    names, or use -All to change every host in the pool. Supports -WhatIf / -Confirm.
.PARAMETER ResourceGroupName
    Resource group of the host pool.
.PARAMETER HostPoolName
    Host pool name.
.PARAMETER SessionHostName
    One or more session host names (e.g. avd-contoso-0.contoso.com).
.PARAMETER All
    Apply to every session host in the pool.
.PARAMETER Mode
    On (block new sessions) or Off (allow new sessions).
.EXAMPLE
    ./Set-AvdDrainMode.ps1 -ResourceGroupName rg-avd-prod -HostPoolName hp-contoso-pooled -SessionHostName avd-contoso-0.contoso.com -Mode On -WhatIf
.EXAMPLE
    ./Set-AvdDrainMode.ps1 -ResourceGroupName rg-avd-prod -HostPoolName hp-contoso-pooled -All -Mode Off
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByName')]
param(
    [Parameter(Mandatory)][string]$ResourceGroupName,
    [Parameter(Mandatory)][string]$HostPoolName,
    [Parameter(Mandatory, ParameterSetName = 'ByName')][string[]]$SessionHostName,
    [Parameter(Mandatory, ParameterSetName = 'All')][switch]$All,
    [Parameter(Mandatory)][ValidateSet('On', 'Off')][string]$Mode
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { throw 'Not connected. Run Connect-M365Admin -Service Azure first.' }

$hosts = @(Get-AzWvdSessionHost -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName)
if (-not $All) {
    $hosts = @($hosts | Where-Object { ($_.Name -split '/')[-1] -in $SessionHostName })
    $missing = $SessionHostName | Where-Object { $_ -notin ($hosts.Name | ForEach-Object { ($_ -split '/')[-1] }) }
    if ($missing) { Write-Warning "Not found in $HostPoolName`: $($missing -join ', ')" }
}
$allow = $Mode -eq 'Off'

foreach ($h in $hosts) {
    $name = ($h.Name -split '/')[-1]
    if ($h.AllowNewSession -eq $allow) { Write-Verbose "$name already has drain mode $Mode"; continue }
    if ($PSCmdlet.ShouldProcess($name, "Set drain mode $Mode")) {
        Update-AzWvdSessionHost -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -Name $name -AllowNewSession:$allow | Out-Null
        Write-Information "$name drain mode $Mode (sessions now: $($h.Session))" -InformationAction Continue
    }
}
