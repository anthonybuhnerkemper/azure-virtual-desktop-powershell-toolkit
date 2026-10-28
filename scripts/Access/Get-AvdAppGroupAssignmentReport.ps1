#Requires -Version 7.4
#Requires -Modules Az.Accounts, Az.Resources, Az.DesktopVirtualization
<#
.SYNOPSIS
    Reports who can see each Azure Virtual Desktop application group.
.DESCRIPTION
    Read-only. Users see a desktop or RemoteApp when they hold the Desktop Virtualization User role
    on its application group. This script lists every assignment, says whether it is a group or a
    direct user assignment, and flags application groups with no assignments and direct user
    assignments (groups are easier to manage). For personal host pools, the session host report
    shows which user owns each host. Exports CSV.
.PARAMETER ResourceGroupName
    Optional. Limit the report to one resource group.
.PARAMETER OutputFolder
    Folder for CSV output. Defaults to ./output.
.EXAMPLE
    ./Get-AvdAppGroupAssignmentReport.ps1
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName,
    [string]$OutputFolder = (Join-Path (Get-Location) 'output')
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { throw 'Not connected. Run Connect-M365Admin -Service Azure first.' }
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

$scope = @{}
if ($ResourceGroupName) { $scope.ResourceGroupName = $ResourceGroupName }
$rows = foreach ($ag in @(Get-AzWvdApplicationGroup @scope)) {
    $assignments = @(Get-AzRoleAssignment -Scope $ag.Id -RoleDefinitionName 'Desktop Virtualization User' |
        Where-Object Scope -eq $ag.Id)
    if (-not $assignments) {
        [pscustomobject]@{ AppGroup = $ag.Name; Type = $ag.ApplicationGroupType; HostPool = ($ag.HostPoolArmPath -split '/')[-1]
            Assignee = ''; SignInName = ''; ObjectType = ''; Flag = 'No assignments' }
        continue
    }
    foreach ($a in $assignments) {
        [pscustomobject]@{
            AppGroup   = $ag.Name
            Type       = $ag.ApplicationGroupType
            HostPool   = ($ag.HostPoolArmPath -split '/')[-1]
            Assignee   = $a.DisplayName
            SignInName = $a.SignInName
            ObjectType = $a.ObjectType
            Flag       = if ($a.ObjectType -eq 'User') { 'Direct user assignment' } else { '' }
        }
    }
}

$file = Join-Path $OutputFolder "AvdAppGroupAssignments-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"
$rows | Export-Csv $file -NoTypeInformation
$rows | Format-Table AppGroup, Type, Assignee, ObjectType, Flag -AutoSize
Write-Information "Assignments: $(@($rows | Where-Object Assignee).Count). Flagged rows: $(@($rows | Where-Object Flag).Count). CSV: $file" -InformationAction Continue
