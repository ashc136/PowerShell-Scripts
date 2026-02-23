# ============================================================
# Get-EntraPasswordExpiry.ps1
# Check password expiry for a specific user in Entra ID
# Author: Ash C | 24-02-2026 | V 1.0
# ============================================================

# Microsoft Graph module
if (-not (Get-Module -Name Microsoft.Graph.Users -ErrorAction SilentlyContinue)) {
    try {
        Import-Module Microsoft.Graph.Users -ErrorAction Stop
    } catch {
        Write-Host "Microsoft.Graph module not found. Run: Install-Module Microsoft.Graph -Scope CurrentUser" -ForegroundColor Red
        exit
    }
}

# Connect if not already
if (-not (Get-MgContext)) {
    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
    Connect-MgGraph -Scopes "User.Read.All" -NoWelcome -UseDeviceAuthentication
}

# Prompt for username
$username = Read-Host "`nEnter username (UPN, SAMAccountName, or email)"

Write-Host ""
Write-Host "--- ENTRA ID ---" -ForegroundColor Cyan

try {
    # Try UPN, SAMAccountName, then mail separately
    $entraUser = $null
    $props = "Id,DisplayName,UserPrincipalName,Mail,PasswordPolicies,LastPasswordChangeDateTime,OnPremisesSyncEnabled,AccountEnabled"

    foreach ($q in @(
        "userPrincipalName eq '$username'",
        "onPremisesSamAccountName eq '$username'",
        "mail eq '$username'"
    )) {
        try {
            $result = Get-MgUser -Filter $q -Property $props -ErrorAction Stop | Select-Object -First 1
            if ($result) { $entraUser = $result; break }
        } catch { continue }
    }

    if (-not $entraUser) {
        Write-Host "User '$username' not found in Entra ID." -ForegroundColor Red
    } else {
        $source     = if ($entraUser.OnPremisesSyncEnabled) { "Synced from AD" } else { "Cloud Only" }
        $orgAgeDays = 90  # Update if your tenant password expiry policy differs

        # Account status
        $accountStatus = if ($entraUser.AccountEnabled) { "Enabled" } else { "DISABLED" }
        $accountColour = if ($entraUser.AccountEnabled) { "Green" } else { "Red" }

        Write-Host "Display Name         : $($entraUser.DisplayName)"
        Write-Host "UPN                  : $($entraUser.UserPrincipalName)"
        Write-Host "Account Source       : $source"
        Write-Host "Account Status       : $accountStatus" -ForegroundColor $accountColour
        Write-Host "Last Password Change : $($entraUser.LastPasswordChangeDateTime)"

        if ($entraUser.PasswordPolicies -like "*DisablePasswordExpiration*") {
            Write-Host "Password Expires     : Never" -ForegroundColor Gray
        } elseif ($null -eq $entraUser.LastPasswordChangeDateTime) {
            Write-Host "Password Expires     : Unknown (no last change date recorded)" -ForegroundColor Yellow
        } else {
            $expiryDate = $entraUser.LastPasswordChangeDateTime.AddDays($orgAgeDays)
            $daysLeft   = ($expiryDate - (Get-Date)).Days
            $colour     = if ($daysLeft -le 0) { "Red" } elseif ($daysLeft -le 14) { "Yellow" } else { "Green" }

            Write-Host "Password Expires     : $expiryDate" -ForegroundColor $colour
            Write-Host "Days Remaining       : $daysLeft" -ForegroundColor $colour
        }
    }

} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Write-Host ""
