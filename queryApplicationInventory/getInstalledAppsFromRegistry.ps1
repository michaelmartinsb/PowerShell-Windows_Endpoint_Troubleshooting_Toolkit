# Define an array of registry paths to query for installed applications.
# Includes both the standard location and the location for 32-bit applications on 64-bit systems.

$paths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

# Query the defined registry paths for installed applications. For each path, get the properties of all items (* wildcard),
# filter out entries without a display name (to ignore system components that are not applications),
# select the display name and version for those applications, and then sort the list by application name.

$installedWin32Apps = $paths | ForEach-Object {
    # Retrieve all properties for items in each path
    Get-ItemProperty $_\*
} | Where-Object {
    $_.DisplayName -ne $null # Filter to include only items with a display name
} | Select-Object @{Name='Name';Expression={$_.DisplayName}}, @{Name='Version';Expression={$_.DisplayVersion}} | Sort-Object Name

# Query installed UWP apps using Get-AppxPackage
$installedUWPApps = Get-AppxPackage | Select-Object @{Name='Name';Expression={$_.Name}}, @{Name='Version';Expression={$_.Version}} | Sort-Object Name

# Combine the lists of installed Win32 apps and UWP apps
$installedApps = $installedWin32Apps + $installedUWPApps

# Output the list of installed applications and their version numbers.
$installedApps
