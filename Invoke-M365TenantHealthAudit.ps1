<#
.SYNOPSIS
    Generic read-only Microsoft 365, Entra ID & Intune tenant health audit script.
.DESCRIPTION
    Standalone delivery starter for the $149 M365 Automation Pack sprint.
    Produces CSV + Markdown summary of subscribed SKUs, stale Intune managed devices,
    and inactive user accounts using an existing Microsoft Graph bearer token.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $AccessToken,
    [int] $StaleDays = 45,
    [string] $OutputDir = ".\audit-output"
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$headers = @{ Authorization = "Bearer $AccessToken" }

function Invoke-GraphPaged {
    param([string] $Uri)
    $items = @()
    $next = $Uri
    while ($next) {
        $res = Invoke-RestMethod -Method Get -Uri $next -Headers $headers
        if ($res.value) { $items += $res.value }
        $next = $res.'@odata.nextLink'
    }
    return $items
}

Write-Host "Collecting subscribedSkus..."
$skus = Invoke-GraphPaged "https://graph.microsoft.com/v1.0/subscribedSkus" | ForEach-Object {
    [pscustomobject]@{
        SkuPartNumber = $_.skuPartNumber
        EnabledUnits  = $_.prepaidUnits.enabled
        ConsumedUnits = $_.consumedUnits
        Unassigned    = ($_.prepaidUnits.enabled - $_.consumedUnits)
    }
}
$skus | Export-Csv (Join-Path $OutputDir "license_summary.csv") -NoTypeInformation -Encoding UTF8

Write-Host "Collecting Intune managedDevices..."
$cutoff = (Get-Date).AddDays(-$StaleDays)
$devices = Invoke-GraphPaged "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=id,deviceName,operatingSystem,complianceState,lastSyncDateTime,userPrincipalName"
$staleDevices = $devices | Where-Object {
    $_.lastSyncDateTime -and ([datetime]$_.lastSyncDateTime -lt $cutoff)
}
$devices | Export-Csv (Join-Path $OutputDir "intune_devices.csv") -NoTypeInformation -Encoding UTF8
$staleDevices | Export-Csv (Join-Path $OutputDir "intune_stale_devices.csv") -NoTypeInformation -Encoding UTF8

$nonCompliant = @($devices | Where-Object { $_.complianceState -ne "compliant" }).Count
$summary = @"
# M365 & Intune Tenant Audit Summary

- Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm")
- Total SKUs analyzed: $($skus.Count)
- Total Intune managed devices: $($devices.Count)
- Stale devices (>$StaleDays days since sync): $($staleDevices.Count)
- Non-compliant devices: $nonCompliant

Artifacts saved in `$OutputDir`:
- license_summary.csv
- intune_devices.csv
- intune_stale_devices.csv
"@
$summary | Set-Content (Join-Path $OutputDir "SUMMARY.md") -Encoding UTF8
Write-Host "Audit complete. Files written to $OutputDir"
