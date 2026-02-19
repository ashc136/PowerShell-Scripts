<#
.SYNOPSIS
    Removes all registry entries, services, and folders associated with the Microsoft Defender for Identity sensor
    (formerly Azure Advanced Threat Protection Sensor).

.DESCRIPTION
    This script performs a full cleanup of MDI sensor residual components that are not removed by the standard
    uninstaller. It stops and deletes associated services, removes registry entries based on GUIDs found across
    multiple registry paths, deletes Package Cache folders, and removes the installation directory.

    All actions are logged to a timestamped log file in the script's directory for auditing purposes.

    Use this script when:
    - The MDI sensor is showing as Disconnected in the portal and cannot be repaired
    - A previous uninstall left behind residual services or registry keys blocking reinstallation
    - The sensor is stuck on an old version (common on Server 2016) and a clean reinstall is required

.PARAMETER None
    This script does not accept parameters. All actions are confirmed interactively.

.NOTES
    Version:    2.0
    Author:     Ash C
    Date:       19/02/2026
    
    Based on original concept by Sicheng Zhao (Microsoft Support, 2024).
    This version includes additional improvements:
      - Timestamped log file names to preserve history across multiple runs
      - Pre-flight check to confirm running as Administrator
      - Improved service detection before attempting deletion
      - Summary report at end of script showing what was and wasn't found
      - Handles both old (aatpsensor) and new (Microsoft.Tri.Sensor) service names

.EXAMPLE
    .\Clean-MDI-Sensor.ps1
    Run the script interactively. You will be prompted to confirm each major action.

.LINK
    https://learn.microsoft.com/en-us/defender-for-identity/deploy/install-sensor
#>

#Requires -RunAsAdministrator

# ─────────────────────────────────────────────
# Script variables
# ─────────────────────────────────────────────
$timestamp   = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile     = Join-Path $PSScriptRoot "MdiCleanupLog_$timestamp.txt"
$searchTerm  = "Azure Advanced Threat Protection Sensor"
$summary     = @{
    ServicesDeleted   = @()
    ServicesMissing   = @()
    GUIDsFound        = @()
    RegistryDeleted   = @()
    RegistryMissing   = @()
    CacheFolders      = @()
    InstallFolder     = $null
}

# ─────────────────────────────────────────────
# Functions
# ─────────────────────────────────────────────

function Write-Log {
    param ([string]$message, [string]$level = "INFO")
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$level] $message"
    Add-Content -Path $logFile -Value $entry
    switch ($level) {
        "WARN"  { Write-Warning $message }
        "ERROR" { Write-Host $message -ForegroundColor Red }
        default { Write-Host $message }
    }
}

function Delete-Service {
    param ([string]$serviceName)

    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if (-not $service) {
        Write-Log "Service '$serviceName' not found — skipping." "WARN"
        $summary.ServicesMissing += $serviceName
        return
    }

    try {
        Write-Log "Stopping service '$serviceName'..."
        sc.exe stop $serviceName | Out-Null

        $waitTime = 0
        while ((Get-Service -Name $serviceName -ErrorAction SilentlyContinue).Status -ne 'Stopped' -and $waitTime -lt 60) {
            Start-Sleep -Seconds 5
            $waitTime += 5
            Write-Log "Waiting for '$serviceName' to stop... ($waitTime seconds)"
        }

        if ((Get-Service -Name $serviceName -ErrorAction SilentlyContinue).Status -ne 'Stopped') {
            Write-Log "Timed out waiting for '$serviceName' to stop." "ERROR"
            return
        }

        sc.exe delete $serviceName | Out-Null
        Start-Sleep -Seconds 3

        if (-not (Get-Service -Name $serviceName -ErrorAction SilentlyContinue)) {
            Write-Log "Service '$serviceName' successfully deleted."
            $summary.ServicesDeleted += $serviceName
        } else {
            Write-Log "Service '$serviceName' could not be deleted." "ERROR"
        }
    } catch {
        Write-Log "Error processing service '$serviceName': $_" "ERROR"
    }
}

function Find-GUIDs {
    $registryPaths = @(
        "HKLM:\SOFTWARE\Classes\Installer\Products\",
        "HKLM:\SOFTWARE\Classes\Installer\Features\",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\",
        "HKLM:\SOFTWARE\Classes\Installer\Dependencies\"
    )

    $guids = @()
    foreach ($path in $registryPaths) {
        $subKeys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
        foreach ($key in $subKeys) {
            $props = Get-ItemProperty -Path ($path + $key.PSChildName) -ErrorAction SilentlyContinue
            if ($props.DisplayName -eq $searchTerm -or $props.ProductName -eq $searchTerm) {
                Write-Log "Found GUID: $($key.PSChildName)"
                $guids += $key.PSChildName
            }
        }
    }
    return $guids | Select-Object -Unique
}

function Delete-RegistryKeys {
    param ([string]$guid)

    $registryPaths = @(
        "HKLM:\SOFTWARE\Classes\Installer\Products\",
        "HKLM:\SOFTWARE\Classes\Installer\Features\",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\",
        "HKLM:\SOFTWARE\Classes\Installer\Dependencies\"
    )

    foreach ($path in $registryPaths) {
        $regKey = "$path$guid"
        if (Test-Path $regKey) {
            Remove-Item -Path $regKey -Recurse -Force
            Write-Log "Deleted registry key: $regKey"
            $summary.RegistryDeleted += $regKey
        } else {
            Write-Log "Registry key not found: $regKey" "WARN"
            $summary.RegistryMissing += $regKey
        }
    }
}

function Delete-CacheFolder {
    param ([string]$guid)

    $path = "C:\ProgramData\Package Cache\$guid"
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force
        Write-Log "Deleted cache folder: $path"
        $summary.CacheFolders += $path
    } else {
        Write-Log "Cache folder not found: $path" "WARN"
    }
}

function Delete-InstallFolder {
    $path = "C:\Program Files\Azure Advanced Threat Protection Sensor"
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force
        Write-Log "Deleted installation folder: $path"
        $summary.InstallFolder = "Deleted"
    } else {
        Write-Log "Installation folder not found: $path" "WARN"
        $summary.InstallFolder = "Not found"
    }
}

function Show-Summary {
    Write-Host ""
    Write-Host "─────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host " CLEANUP SUMMARY" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "Services deleted:    $($summary.ServicesDeleted -join ', ')"
    Write-Host "Services not found:  $($summary.ServicesMissing -join ', ')"
    Write-Host "GUIDs found:         $($summary.GUIDsFound.Count)"
    Write-Host "Registry keys deleted: $($summary.RegistryDeleted.Count)"
    Write-Host "Cache folders deleted: $($summary.CacheFolders.Count)"
    Write-Host "Install folder:      $($summary.InstallFolder)"
    Write-Host "Log file:            $logFile"
    Write-Host "─────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host ""
}

# ─────────────────────────────────────────────
# Main Execution
# ─────────────────────────────────────────────

Write-Log "═══════════════════════════════════════════"
Write-Log "MDI Sensor Cleanup Script v2.0 - Ash C"
Write-Log "Computer: $env:COMPUTERNAME | User: $env:USERNAME"
Write-Log "═══════════════════════════════════════════"

# Step 1 — Services
$confirmation = Read-Host "`nStop and delete MDI sensor services? (yes/no)"
if ($confirmation -ne 'yes') {
    Write-Log "Aborted by user at service deletion step." "WARN"
    exit
}

# Handle both old and new service names
Delete-Service -serviceName "aatpsensor"
Delete-Service -serviceName "aatpsensorupdater"
Delete-Service -serviceName "Microsoft.Tri.Sensor"
Delete-Service -serviceName "Microsoft.Tri.Sensor.Updater"

# Step 2 — Registry and Cache
$guids = Find-GUIDs
$summary.GUIDsFound = $guids

if ($guids.Count -gt 0) {
    Write-Host "`nFound $($guids.Count) GUID(s): $($guids -join ', ')"
    $confirmation = Read-Host "Delete all associated registry keys and cache folders? (yes/no)"
    if ($confirmation -ne 'yes') {
        Write-Log "Aborted by user at registry deletion step." "WARN"
        exit
    }
    foreach ($guid in $guids) {
        Delete-RegistryKeys -guid $guid
        Delete-CacheFolder -guid $guid
    }
} else {
    Write-Log "No GUIDs found for '$searchTerm' — registry may already be clean." "WARN"
}

# Step 3 — Install Folder
$confirmation = Read-Host "`nDelete the MDI sensor installation folder? (yes/no)"
if ($confirmation -ne 'yes') {
    Write-Log "Aborted by user at folder deletion step." "WARN"
    exit
}
Delete-InstallFolder

# Done
Write-Log "Script completed successfully."
Show-Summary