#Requires -Version 7.4
<#
.SYNOPSIS
    Disconnects every session opened by Connect-M365Admin.
.DESCRIPTION
    Dot-source this file, then call Disconnect-M365Admin. Sessions that are not open are skipped.
.EXAMPLE
    . ./scripts/Connect/Disconnect-M365Admin.ps1
    Disconnect-M365Admin
#>
function Disconnect-M365Admin {
    [CmdletBinding()]
    param()
    $steps = [ordered]@{
        'Disconnect-MgGraph'         = @{}
        'Disconnect-ExchangeOnline'  = @{ Confirm = $false }
        'Disconnect-SPOService'      = @{}
        'Disconnect-PnPOnline'       = @{}
        'Disconnect-MicrosoftTeams'  = @{}
        'Disconnect-AzAccount'       = @{}
    }
    foreach ($cmd in $steps.Keys) {
        if (Get-Command $cmd -ErrorAction SilentlyContinue) {
            $splat = $steps[$cmd]
            try { & $cmd @splat -ErrorAction Stop | Out-Null; Write-Verbose "$cmd done" }
            catch { Write-Verbose "$cmd skipped: $($_.Exception.Message)" }
        }
    }
    Write-Information 'Disconnected.' -InformationAction Continue
}
