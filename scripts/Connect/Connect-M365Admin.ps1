#Requires -Version 7.4
<#
.SYNOPSIS
    Connects to the Microsoft 365 admin endpoints used by this toolkit.

.DESCRIPTION
    Dot-source this file, then call Connect-M365Admin. This follows the same pattern as
    graph-powershell7-admin-toolkit (https://github.com/anthonybuhnerkemper/graph-powershell7-admin-toolkit),
    extended with SharePoint Online, PnP, Teams and Azure endpoints.

    Two modes:
      * Certificate (app-only, default): -TenantId, -ClientId and either -CertificateThumbprint
        (cert in CurrentUser\My on Windows) or -CertificatePath (PFX; password read from the
        M365_CERT_PASSWORD environment variable).
      * Interactive (delegated): -Interactive, optionally -UserPrincipalName.

    Values can also come from environment variables: M365_TENANT_ID, M365_CLIENT_ID,
    M365_CERT_THUMBPRINT, M365_ORGANIZATION, M365_SPO_ADMIN_URL, AZ_SUBSCRIPTION_ID.
    No secrets are stored in this repo.

.PARAMETER Service
    Services to connect: Graph, ExchangeOnline, Purview, SharePoint (SPO module), PnP, Teams, Azure.

.PARAMETER SharePointAdminUrl
    SharePoint admin center URL, for example https://contoso-admin.sharepoint.com.

.PARAMETER GraphScopes
    Delegated Graph scopes requested in interactive mode.

.EXAMPLE
    . ./scripts/Connect/Connect-M365Admin.ps1
    Connect-M365Admin -Service Graph, PnP -Interactive -ClientId 00000000-0000-0000-0000-000000000000

.EXAMPLE
    $env:M365_TENANT_ID = '00000000-0000-0000-0000-000000000000'
    $env:M365_CLIENT_ID = '00000000-0000-0000-0000-000000000000'
    $env:M365_CERT_THUMBPRINT = '0000000000000000000000000000000000000000'
    $env:M365_ORGANIZATION = 'contoso.onmicrosoft.com'
    Connect-M365Admin -Service Graph, ExchangeOnline

.NOTES
    Install only the modules for the services you use: Microsoft.Graph.Authentication,
    ExchangeOnlineManagement 3.x, Microsoft.Online.SharePoint.PowerShell, PnP.PowerShell 2.x/3.x,
    MicrosoftTeams 6.x, Az.Accounts.
#>

function Connect-M365Admin {
    [CmdletBinding()]
    param(
        [ValidateSet('Graph', 'ExchangeOnline', 'Purview', 'SharePoint', 'PnP', 'Teams', 'Azure')]
        [string[]]$Service = @('Graph'),

        [string]$TenantId = $env:M365_TENANT_ID,
        [string]$ClientId = $env:M365_CLIENT_ID,
        [string]$CertificateThumbprint = $env:M365_CERT_THUMBPRINT,
        [string]$CertificatePath,
        [string]$Organization = $env:M365_ORGANIZATION,
        [string]$SharePointAdminUrl = $env:M365_SPO_ADMIN_URL,
        [string]$SubscriptionId = $env:AZ_SUBSCRIPTION_ID,

        [switch]$Interactive,
        [string]$UserPrincipalName,
        [string[]]$GraphScopes = @('User.Read.All', 'Directory.Read.All', 'AuditLog.Read.All', 'Reports.Read.All')
    )

    $ErrorActionPreference = 'Stop'

    $certificate = $null
    if (-not $Interactive) {
        foreach ($name in 'TenantId', 'ClientId') {
            if (-not (Get-Variable -Name $name -ValueOnly)) {
                throw "Missing $name. Pass it as a parameter or set the matching M365_* environment variable."
            }
        }
        if ($CertificatePath) {
            $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
                (Resolve-Path $CertificatePath).Path, $env:M365_CERT_PASSWORD)
        }
        elseif (-not $CertificateThumbprint) {
            throw 'Provide -CertificateThumbprint or -CertificatePath for app-only auth.'
        }
    }
    if ($Service -match 'SharePoint|PnP' -and -not $SharePointAdminUrl) {
        throw 'Provide -SharePointAdminUrl (or M365_SPO_ADMIN_URL), e.g. https://contoso-admin.sharepoint.com'
    }

    if ('Graph' -in $Service) {
        if ($Interactive) { Connect-MgGraph -Scopes $GraphScopes -NoWelcome }
        elseif ($certificate) { Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -Certificate $certificate -NoWelcome }
        else { Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome }
        $ctx = Get-MgContext
        Write-Information "Graph: $($ctx.AuthType) as $($ctx.Account ?? $ctx.AppName)" -InformationAction Continue
    }

    $exoParams = @{ ShowBanner = $false }
    if ($Interactive) {
        if ($UserPrincipalName) { $exoParams.UserPrincipalName = $UserPrincipalName }
    }
    elseif ($Service -match 'ExchangeOnline|Purview') {
        if (-not $Organization) { throw 'Provide -Organization (e.g. contoso.onmicrosoft.com) for app-only Exchange/Purview.' }
        $exoParams.AppId = $ClientId
        $exoParams.Organization = $Organization
        if ($certificate) { $exoParams.Certificate = $certificate } else { $exoParams.CertificateThumbprint = $CertificateThumbprint }
    }
    if ('ExchangeOnline' -in $Service) {
        Connect-ExchangeOnline @exoParams
        Write-Information 'Exchange Online: connected' -InformationAction Continue
    }
    if ('Purview' -in $Service) {
        $ippsParams = $exoParams.Clone()
        $ippsParams.Remove('ShowBanner')
        Connect-IPPSSession @ippsParams
        Write-Information 'Purview (IPPS): connected' -InformationAction Continue
    }

    if ('SharePoint' -in $Service) {
        if ($Interactive) { Connect-SPOService -Url $SharePointAdminUrl }
        else {
            # App-only SPO requires a recent Microsoft.Online.SharePoint.PowerShell build and a thumbprint.
            Connect-SPOService -Url $SharePointAdminUrl -ClientId $ClientId -Tenant $TenantId -CertificateThumbprint $CertificateThumbprint
        }
        Write-Information "SharePoint Online (SPO): connected to $SharePointAdminUrl" -InformationAction Continue
    }

    if ('PnP' -in $Service) {
        # PnP.PowerShell needs your own Entra app registration (ClientId), even for interactive sign-in.
        if (-not $ClientId) { throw 'PnP.PowerShell requires -ClientId (your own app registration).' }
        if ($Interactive) { Connect-PnPOnline -Url $SharePointAdminUrl -Interactive -ClientId $ClientId }
        elseif ($CertificatePath) {
            $securePassword = [securestring]::new()
            foreach ($ch in ([string]$env:M365_CERT_PASSWORD).ToCharArray()) { $securePassword.AppendChar($ch) }
            Connect-PnPOnline -Url $SharePointAdminUrl -ClientId $ClientId -Tenant $Organization -CertificatePath $CertificatePath -CertificatePassword $securePassword
        }
        else { Connect-PnPOnline -Url $SharePointAdminUrl -ClientId $ClientId -Tenant $Organization -Thumbprint $CertificateThumbprint }
        Write-Information "PnP: connected to $SharePointAdminUrl" -InformationAction Continue
    }

    if ('Teams' -in $Service) {
        if ($Interactive) { Connect-MicrosoftTeams | Out-Null }
        elseif ($certificate) { Connect-MicrosoftTeams -TenantId $TenantId -ApplicationId $ClientId -Certificate $certificate | Out-Null }
        else { Connect-MicrosoftTeams -TenantId $TenantId -ApplicationId $ClientId -CertificateThumbprint $CertificateThumbprint | Out-Null }
        Write-Information 'Microsoft Teams: connected' -InformationAction Continue
    }

    if ('Azure' -in $Service) {
        $azParams = @{}
        if ($TenantId) { $azParams.TenantId = $TenantId }
        if ($SubscriptionId) { $azParams.Subscription = $SubscriptionId }
        if (-not $Interactive) {
            $azParams.ServicePrincipal = $true
            $azParams.ApplicationId = $ClientId
            $azParams.CertificateThumbprint = $CertificateThumbprint
        }
        Connect-AzAccount @azParams | Out-Null
        Write-Information "Azure: connected ($((Get-AzContext).Subscription.Name))" -InformationAction Continue
    }
}
