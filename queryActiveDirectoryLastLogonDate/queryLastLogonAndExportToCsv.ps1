# Import the Active Directory module
Import-Module ActiveDirectory

# Define the output CSV file path
$outputCsv = "C:\users\mmartins\Downloads\Allcomputers_last_logon.csv"

# Get all domain controllers in the domain
$domainControllers = Get-ADDomainController -Filter *

# Get all computers in the domain
$computers = Get-ADComputer -Filter * -Properties Name

# Create an array to store the results
$results = @()

# Function to get the most recent logon time from all domain controllers
function Get-MostRecentLogonTime {
    param (
        [string]$computerName
    )
    $mostRecentLogon = $null
    foreach ($dc in $domainControllers) {
        $lastLogon = Get-ADComputer -Identity $computerName -Server $dc.HostName -Properties LastLogon | Select-Object -ExpandProperty LastLogon
        if ($lastLogon -and (!$mostRecentLogon -or $lastLogon -gt $mostRecentLogon)) {
            $mostRecentLogon = $lastLogon
        }
    }
    return $mostRecentLogon
}

# Loop through each computer and collect the name and most recent last logon date
foreach ($computer in $computers) {
    $mostRecentLogon = Get-MostRecentLogonTime -computerName $computer.Name
    $results += [PSCustomObject]@{
        ComputerName  = $computer.Name
        LastLogonDate = if ($mostRecentLogon) { [DateTime]::FromFileTime($mostRecentLogon) } else { $null }
    }
}

# Export the results to a CSV file
$results | Export-Csv -Path $outputCsv -NoTypeInformation

Write-Output "Export completed. Results saved to $outputCsv"
