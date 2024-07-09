param (
    [Parameter(Mandatory=$true)]
    [string]$AppName
)

# Define an array of registry paths to query for installed applications.
$registryPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

# Function to find the uninstall string for the specified application
function Get-UninstallString {
    param (
        [string]$appName,
        [string[]]$registryPaths
    )
    
    foreach ($path in $registryPaths) {
        if (Test-Path $path) {
            $app = Get-ItemProperty $path\* |
                   Where-Object { $_.DisplayName -eq $appName } |
                   Select-Object -First 1
            if ($app) {
                return $app.UninstallString
            }
        }
    }
    return $null
}

# Get the uninstall string for the specified application
$uninstallString = Get-UninstallString -appName $AppName -registryPaths $registryPaths

if ($uninstallString) {
    Write-Output "Found uninstall string: $uninstallString"
    try {
        # Execute the uninstall string
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $uninstallString -Wait -NoNewWindow
        Write-Output "$AppName has been successfully uninstalled."
    } catch {
        Write-Error "Failed to uninstall $AppName. Error: $_"
    }
} else {
    Write-Error "Uninstall string for $AppName not found."
}
