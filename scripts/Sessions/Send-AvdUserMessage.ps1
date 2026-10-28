#Requires -Version 7.4
#Requires -Modules Az.Accounts, Az.DesktopVirtualization
<#
.SYNOPSIS
    Sends a pop-up message to users signed in to Azure Virtual Desktop session hosts.
.DESCRIPTION
    Sends the message to every active session in the host pool, or only to sessions on the named
    session hosts. Handy before maintenance ("please save your work, this host restarts in 15
    minutes"). Disconnected sessions are skipped because nobody would see the message.
    Supports -WhatIf / -Confirm.
.PARAMETER ResourceGroupName
    Resource group of the host pool.
.PARAMETER HostPoolName
    Host pool name.
.PARAMETER SessionHostName
    Optional. One or more session host names (as shown in the portal, e.g. avd-contoso-0.contoso.com).
.PARAMETER Title
    Message title.
.PARAMETER Message
    Message body.
.EXAMPLE
    ./Send-AvdUserMessage.ps1 -ResourceGroupName rg-avd-prod -HostPoolName hp-contoso-pooled -Title 'Maintenance' -Message 'Please save your work. This desktop restarts at 6 PM.' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
param(
    [Parameter(Mandatory)][string]$ResourceGroupName,
    [Parameter(Mandatory)][string]$HostPoolName,
    [string[]]$SessionHostName,
    [Parameter(Mandatory)][string]$Title,
    [Parameter(Mandatory)][string]$Message
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { throw 'Not connected. Run Connect-M365Admin -Service Azure first.' }

$sessions = @(Get-AzWvdUserSession -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName |
    Where-Object SessionState -eq 'Active')
$sent = 0
foreach ($s in $sessions) {
    $parts = $s.Name -split '/'
    $hostName = $parts[1]; $id = $parts[2]
    if ($SessionHostName -and $hostName -notin $SessionHostName) { continue }
    if ($PSCmdlet.ShouldProcess("$($s.UserPrincipalName) on $hostName", "Send message '$Title'")) {
        Send-AzWvdUserSessionMessage -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName `
            -SessionHostName $hostName -UserSessionId $id -MessageTitle $Title -MessageBody $Message
        $sent++
    }
}
Write-Information "Messages sent: $sent" -InformationAction Continue
