#Requires -Version 7.4
#Requires -Modules Az.Accounts, Az.DesktopVirtualization
<#
.SYNOPSIS
    Lists active and disconnected user sessions in an Azure Virtual Desktop host pool.
.DESCRIPTION
    Read-only. Shows who is signed in to which session host, the session state, application type
    and when the session was created. Use -UserPrincipalName to find one user quickly when they
    call the help desk. Exports CSV.
.PARAMETER ResourceGroupName
    Resource group of the host pool.
.PARAMETER HostPoolName
    Host pool name.
.PARAMETER UserPrincipalName
    Optional. Only show sessions for this user.
.PARAMETER State
    All (default), Active or Disconnected.
.PARAMETER OutputFolder
    Folder for CSV output. Defaults to ./output.
.EXAMPLE
    ./Get-AvdUserSessionReport.ps1 -ResourceGroupName rg-avd-prod -HostPoolName hp-contoso-pooled
.EXAMPLE
    ./Get-AvdUserSessionReport.ps1 -ResourceGroupName rg-avd-prod -HostPoolName hp-contoso-pooled -UserPrincipalName adele.vance@contoso.com
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ResourceGroupName,
    [Parameter(Mandatory)][string]$HostPoolName,
    [string]$UserPrincipalName,
    [ValidateSet('All', 'Active', 'Disconnected')][string]$State = 'All',
    [string]$OutputFolder = (Join-Path (Get-Location) 'output')
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { throw 'Not connected. Run Connect-M365Admin -Service Azure first.' }
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

$sessions = @(Get-AzWvdUserSession -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName)
if ($UserPrincipalName) { $sessions = @($sessions | Where-Object UserPrincipalName -eq $UserPrincipalName) }
if ($State -ne 'All') { $sessions = @($sessions | Where-Object SessionState -eq $State) }

$rows = foreach ($s in $sessions) {
    $parts = $s.Name -split '/'
    [pscustomobject]@{
        User            = $s.UserPrincipalName
        SessionHost     = $parts[1]
        SessionId       = $parts[2]
        State           = $s.SessionState
        ApplicationType = $s.ApplicationType
        CreatedUtc      = if ($s.CreateTime) { ([datetime]$s.CreateTime).ToUniversalTime() } else { $null }
    }
}

$file = Join-Path $OutputFolder "AvdUserSessions-$HostPoolName-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"
$rows | Sort-Object SessionHost, User | Export-Csv $file -NoTypeInformation
$rows | Sort-Object SessionHost, User | Format-Table -AutoSize
Write-Information "Sessions: $(@($rows).Count) ($(@($rows | Where-Object State -eq 'Active').Count) active). CSV: $file" -InformationAction Continue
