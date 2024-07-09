param (
    [Parameter(Mandatory=$true)]
    [string]$AppName
)

# Define the log file path
$logDirectory = "C:\temp"
$logFile = "$logDirectory\uninstall_log.txt"

# Ensure the log directory exists
if (-Not (Test-Path $logDirectory)) {
    New-Item -Path $logDirectory -ItemType Directory
}

# Log a message to the log file
function Log-Message {
    param (
        [string]$message
    )
    Add-Content -Path $logFile -Value "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) - $message"
}

Log-Message "Starting uninstallation process for $AppName."

# Define an array of registry paths to query for installed applications.
$registryPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

# Function to find the uninstall strings for the specified application
function Get-UninstallStrings {
    param (
        [string]$appName,
        [string[]]$registryPaths
    )
    
    $uninstallStrings = @()
    foreach ($path in $registryPaths) {
        if (Test-Path $path) {
            $apps = Get-ItemProperty $path\* |
                    Where-Object { $_.DisplayName -ieq $appName }
            foreach ($app in $apps) {
                $uninstallStrings += $app.UninstallString
                Log-Message "Found uninstall string: $($app.DisplayName) - $($app.UninstallString)"
            }
        }
    }
    return $uninstallStrings
}

# Function to attempt silent uninstallation with msiexec
function Attempt-SilentUninstall {
    param (
        [string]$uninstallString
    )

    if ($uninstallString -match "msiexec") {
        # Handle msiexec command specifically for uninstallation
        $uninstallString = $uninstallString -replace "/I", "/X"
        $silentUninstallString = "$uninstallString /quiet /qn"
    } else {
        # General case
        $silentUninstallString = "$uninstallString /S"
    }

    try {
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $silentUninstallString -Wait -NoNewWindow -ErrorAction Stop
        Log-Message "Silent uninstallation attempted with: $silentUninstallString"
        return $true
    } catch {
        Log-Message "Silent uninstallation failed: $_"
        return $false
    }
}

# Function to uninstall .msix/.appx packages
function Remove-AppxPackageByName {
    param (
        [string]$appName
    )

    $appxPackages = Get-AppxPackage -Name $appName
    if ($appxPackages) {
        foreach ($package in $appxPackages) {
            try {
                Log-Message "Attempting to remove package: $($package.Name)"
                Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
                Log-Message "$($package.Name) has been successfully uninstalled."
            } catch {
                Log-Message "Failed to uninstall $($package.Name). Error: $_"
            }
        }
    } else {
        Log-Message "No Appx package found with the name $appName."
    }
}

# Get the uninstall strings for the specified application
$uninstallStrings = Get-UninstallStrings -appName $AppName -registryPaths $registryPaths

if ($uninstallStrings.Count -gt 0) {
    foreach ($uninstallString in $uninstallStrings) {
        Log-Message "Processing uninstall string: $uninstallString"
        
        $silentUninstallSucceeded = Attempt-SilentUninstall -uninstallString $uninstallString
        
        if (-Not $silentUninstallSucceeded) {
            try {
                # Execute the normal uninstall string
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $uninstallString -Wait -NoNewWindow
                Log-Message "$AppName has been successfully uninstalled."
            } catch {
                Log-Message "Failed to uninstall $AppName. Error: $_"
            }
        } else {
            Log-Message "$AppName has been successfully uninstalled silently."
        }
    }
} else {
    Log-Message "Uninstall string for $AppName not found in registry. Attempting to uninstall as an AppxPackage."

    # Attempt to uninstall as an AppxPackage
    Remove-AppxPackageByName -appName $AppName
}

Log-Message "Uninstallation process for $AppName completed."
