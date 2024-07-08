# Define an array of registry paths to query for installed applications, including user-specific paths.
$paths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

# Function to get installed applications from registry paths
function Get-InstalledAppsFromRegistry {
    param (
        [string[]]$registryPaths
    )
    $apps = @()
    foreach ($path in $registryPaths) {
        if (Test-Path $path) {
            $apps += Get-ItemProperty $path\* |
                Where-Object { $_.DisplayName -ne $null } |
                Select-Object @{Name='Name';Expression={$_.DisplayName}}, @{Name='Version';Expression={$_.DisplayVersion}}
        }
    }
    return $apps
}

# Query the defined registry paths for installed applications
$installedWin32Apps = Get-InstalledAppsFromRegistry -registryPaths $paths | Sort-Object Name

# Query installed UWP apps using Get-AppxPackage
$installedUWPApps = Get-AppxPackage | Select-Object @{Name='Name';Expression={$_.Name}}, @{Name='Version';Expression={$_.Version}} | Sort-Object Name

# Query installed applications using WMI
$installedWmiApps = Get-WmiObject -Class Win32_Product | Select-Object @{Name='Name';Expression={$_.Name}}, @{Name='Version';Expression={$_.Version}} | Sort-Object Name

# Query installed applications using CIM
$installedCimApps = Get-CimInstance -ClassName Win32_Product | Select-Object @{Name='Name';Expression={$_.Name}}, @{Name='Version';Expression={$_.Version}} | Sort-Object Name

# Combine the lists of installed Win32 apps, UWP apps, WMI apps, and CIM apps
$installedApps = $installedWin32Apps + $installedUWPApps + $installedWmiApps + $installedCimApps

# Remove duplicate entries by Name and Version
$installedApps = $installedApps | Sort-Object Name, Version -Unique

# Output the list of installed applications and their version numbers
$installedApps | Format-Table -AutoSize
