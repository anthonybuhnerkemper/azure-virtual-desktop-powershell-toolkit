#Requires -Version 7.4
#Requires -Modules Az.Accounts, Az.DesktopVirtualization
<#
.SYNOPSIS
    Reports every Azure Virtual Desktop host pool, application group and workspace in a subscription.
.DESCRIPTION
    Read-only. Lists host pools with their type, load balancing, session limit, Start VM on Connect
    and validation settings, plus the application groups linked to each pool and the workspace that
    publishes them. Flags application groups that are not published in any workspace. Exports CSV.
.PARAMETER ResourceGroupName
    Optional. Limit the report to one resource group.
.PARAMETER OutputFolder
    Folder for CSV output. Defaults to ./output.
.EXAMPLE
    ./Get-AvdEnvironmentReport.ps1
.EXAMPLE
    ./Get-AvdEnvironmentReport.ps1 -ResourceGroupName rg-avd-prod
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
$pools = @(Get-AzWvdHostPool @scope)
$appGroups = @(Get-AzWvdApplicationGroup @scope)
$workspaces = @(Get-AzWvdWorkspace @scope)

# Map each application group id to the workspace that publishes it.
$published = @{}
foreach ($ws in $workspaces) {
    foreach ($ref in @($ws.ApplicationGroupReference)) { if ($ref) { $published[$ref.ToLower()] = $ws.Name } }
}

$rows = foreach ($pool in $pools) {
    $linked = @($appGroups | Where-Object { $_.HostPoolArmPath -eq $pool.Id })
    [pscustomobject]@{
        HostPool            = $pool.Name
        ResourceGroup       = ($pool.Id -split '/')[4]
        Location            = $pool.Location
        HostPoolType        = $pool.HostPoolType
        LoadBalancer        = $pool.LoadBalancerType
        MaxSessionLimit     = $pool.MaxSessionLimit
        PreferredAppGroup   = $pool.PreferredAppGroupType
        StartVMOnConnect    = $pool.StartVMOnConnect
        ValidationPool      = $pool.ValidationEnvironment
        AppGroups           = ($linked.Name -join '; ')
        Workspaces          = (($linked | ForEach-Object { $published[$_.Id.ToLower()] }) | Where-Object { $_ } | Sort-Object -Unique) -join '; '
    }
}

$agRows = foreach ($ag in $appGroups) {
    [pscustomobject]@{
        AppGroup      = $ag.Name
        Type          = $ag.ApplicationGroupType
        HostPool      = ($ag.HostPoolArmPath -split '/')[-1]
        Workspace     = $published[$ag.Id.ToLower()]
        NotPublished  = -not $published.ContainsKey($ag.Id.ToLower())
    }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$rows | Export-Csv (Join-Path $OutputFolder "AvdHostPools-$stamp.csv") -NoTypeInformation
$agRows | Export-Csv (Join-Path $OutputFolder "AvdAppGroups-$stamp.csv") -NoTypeInformation
$rows | Format-Table HostPool, HostPoolType, LoadBalancer, MaxSessionLimit, StartVMOnConnect, Workspaces -AutoSize
$orphans = @($agRows | Where-Object NotPublished)
if ($orphans) { Write-Warning "$($orphans.Count) application group(s) are not published in any workspace: $($orphans.AppGroup -join ', ')" }
Write-Information "Host pools: $($rows.Count). Application groups: $($agRows.Count). CSVs in $OutputFolder" -InformationAction Continue
