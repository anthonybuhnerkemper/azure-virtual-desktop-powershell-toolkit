#Requires -Version 7.4
#Requires -Modules Az.Accounts, Az.DesktopVirtualization
<#
.SYNOPSIS
    Reports Azure Virtual Desktop scaling plans and finds host pools that have none.
.DESCRIPTION
    Read-only. Session hosts that run all night cost money. This script lists each scaling plan,
    its time zone, the host pools it is attached to (and whether it is enabled on each), and the
    ramp-up, peak, ramp-down and off-peak start times of every schedule. It then lists host pools
    with no enabled scaling plan, which are the first place to look for savings. Exports CSV.
.PARAMETER ResourceGroupName
    Optional. Limit the report to one resource group.
.PARAMETER OutputFolder
    Folder for CSV output. Defaults to ./output.
.EXAMPLE
    ./Get-AvdScalingPlanReport.ps1
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName,
    [string]$OutputFolder = (Join-Path (Get-Location) 'output')
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { throw 'Not connected. Run Connect-M365Admin -Service Azure first.' }
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

function Format-AvdTime {
    param($Schedule, [string]$Phase)
    # Az.DesktopVirtualization exposes times either as an object (Hour/Minute) or as flattened properties.
    $obj = $Schedule."${Phase}StartTime"
    $hour = if ($obj) { $obj.Hour } else { $Schedule."${Phase}StartTimeHour" }
    $minute = if ($obj) { $obj.Minute } else { $Schedule."${Phase}StartTimeMinute" }
    if ($null -eq $hour) { return '' }
    '{0:D2}:{1:D2}' -f [int]$hour, [int]$minute
}

$scope = @{}
if ($ResourceGroupName) { $scope.ResourceGroupName = $ResourceGroupName }
$plans = @(Get-AzWvdScalingPlan @scope)
$pools = @(Get-AzWvdHostPool @scope)
$covered = @{}

$rows = foreach ($plan in $plans) {
    $refs = @($plan.HostPoolReference)
    foreach ($r in $refs) { if ($r.ScalingPlanEnabled) { $covered[$r.HostPoolArmPath.ToLower()] = $plan.Name } }
    $poolText = ($refs | ForEach-Object { "$(($_.HostPoolArmPath -split '/')[-1]) ($(if ($_.ScalingPlanEnabled) { 'on' } else { 'off' }))" }) -join '; '
    foreach ($s in @($plan.Schedule)) {
        [pscustomobject]@{
            ScalingPlan  = $plan.Name
            TimeZone     = $plan.TimeZone
            HostPools    = $poolText
            Schedule     = $s.Name
            Days         = ($s.DaysOfWeek -join ',')
            RampUp       = Format-AvdTime $s 'RampUp'
            Peak         = Format-AvdTime $s 'Peak'
            RampDown     = Format-AvdTime $s 'RampDown'
            OffPeak      = Format-AvdTime $s 'OffPeak'
            MinHostsPct  = $s.RampUpMinimumHostsPct
            ForceLogoff  = $s.RampDownForceLogoffUser
        }
    }
}

$uncovered = @($pools | Where-Object { -not $covered.ContainsKey($_.Id.ToLower()) } | ForEach-Object {
        [pscustomobject]@{ HostPool = $_.Name; HostPoolType = $_.HostPoolType; ResourceGroup = ($_.Id -split '/')[4] }
    })

$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$rows | Export-Csv (Join-Path $OutputFolder "AvdScalingPlans-$stamp.csv") -NoTypeInformation
$uncovered | Export-Csv (Join-Path $OutputFolder "AvdPoolsWithoutScaling-$stamp.csv") -NoTypeInformation
$rows | Format-Table ScalingPlan, Schedule, Days, RampUp, Peak, RampDown, OffPeak -AutoSize
if ($uncovered) { Write-Warning "Host pools with no enabled scaling plan: $($uncovered.HostPool -join ', ')" }
Write-Information "Scaling plans: $($plans.Count). Host pools without scaling: $($uncovered.Count)." -InformationAction Continue
