# Define an array of registry paths to query for installed applications.
# Includes both the standard location and the location for 32-bit applications on 64-bit systems.

$paths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

# Query the defined registry paths for installed applications. For each path, get the properties of all items (* wildcard),
# filter out entries without a display name (to ignore system components that are not applications),
# select the display name and version for those applications, and then sort the list by application name.

$installedApps = $paths | ForEach-Object { 
    Get-ItemProperty $_\*  # Retrieve all properties for items in each path
} | Where-Object { 
    $_.DisplayName -ne $null  # Filter to include only items with a display name
} | Select-Object DisplayName, DisplayVersion  # Select relevant properties
  | Sort-Object DisplayName  # Sort the results by the display name of the applications

# Output the list of installed applications and their version numbers.

$installedApps