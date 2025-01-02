m<#
.SYNOPSIS
A script to perform application searches using Winget, enumerate results, and install applications by selection, while logging actions to CSV files.

.DESCRIPTION
This script allows the user to search for applications using Winget, displays the results with an enumeration, and
installs the selected application based on the user's choice. It logs the search results and installed applications
to separate CSV files. The script also supports appending new data to the existing files.

.PARAMETER SearchTerm
The term to search for in the Winget repository. The script uses this term to find matching applications.

.EXAMPLE
PS> .\WingetSearchInstaller.ps1 -SearchTerm "notepad"

Searches for applications related to "notepad," lists the results, logs them, and allows the user to install one of the matches.

.NOTES
Author: Epineph
Date: 2025-01-02
Requires: Windows Package Manager (winget)
#>

param (
    [string]$SearchTerm
)

# Paths for the log files
$SearchLogPath = "$PSScriptRoot\WingetSearchResults.csv"
$InstallLogPath = "$PSScriptRoot\WingetInstalledPackages.csv"

function Show-Help {
    Get-Help -Name $MyInvocation.MyCommand.Name -Full
}

function Log-SearchResults {
    param (
        [string[]]$Results
    )

    foreach ($result in $Results) {
        $parsedResult = $result -split "\s{2,}"
        $Name = $parsedResult[0]
        $Id = $parsedResult[1]
        $Version = $parsedResult[2]

        # Append to the CSV file
        $entry = [PSCustomObject]@{
            Name    = $Name
            Id      = $Id
            Version = $Version
            Date    = (Get-Date)
        }
        $entry | Export-Csv -Path $SearchLogPath -Append -NoTypeInformation
    }
}

function Log-InstalledPackages {
    param (
        [string]$AppId
    )

    $entry = [PSCustomObject]@{
        Id      = $AppId
        Date    = (Get-Date)
        Action  = "Installed"
    }
    $entry | Export-Csv -Path $InstallLogPath -Append -NoTypeInformation
}

function Winget-SearchAndInstall {
    param (
        [string]$SearchTerm
    )

    if (-not $SearchTerm) {
        $SearchTerm = Read-Host "Enter the search term for Winget"
    }

    Write-Output "Searching for '$SearchTerm'..."

    # Perform the winget search and parse the results
    $searchResults = winget search $SearchTerm | Out-String

    if (-not $searchResults) {
        Write-Output "No results found for '$SearchTerm'."
        return
    }

    # Split the search results into lines
    $lines = $searchResults -split "`r?`n"

    # Locate the header line
    $headerIndex = $lines | Select-String -Pattern "^\s*Name\s+Id\s+Version" | Select-Object -First 1

    if (-not $headerIndex) {
        Write-Output "No valid entries found for '$SearchTerm'."
        return
    }

    $headerIndexPosition = $lines.IndexOf($headerIndex.Line)
    $results = $lines[($headerIndexPosition + 2)..($lines.Length - 1)] | Where-Object { $_ -match "\S" }

    if (-not $results) {
        Write-Output "No valid entries found for '$SearchTerm'."
        return
    }

    # Log search results to CSV
    Log-SearchResults -Results $results

    $results | ForEach-Object -Begin { $i = 0 } -Process {
        Write-Output "[$i] $_"
        $i++
    }

    $selectedIndexes = Read-Host "Enter the numbers of the applications to install (comma-separated, space-separated, ranges like 1-3, or 'q' to quit)"

    if ($selectedIndexes -eq 'q') {
        Write-Output "Exiting the script."
        return
    }

    $indexes = @()
    $selectedIndexes -split "[ ,]+" | ForEach-Object {
        if ($_ -match "^(\d+)-(\d+)$") {
            $indexes += ($matches[1]..$matches[2])
        } elseif ($_ -match "^\d+$") {
            $indexes += [int]$_
        }
    }

    $indexes = $indexes | Sort-Object -Unique

    foreach ($index in $indexes) {
        if ($index -lt 0 -or $index -ge $results.Count) {
            Write-Output "Invalid selection: $index. Skipping."
            continue
        }

        $selectedApp = $results[$index]
        $appId = ($selectedApp -split "\s{2,}")[1]

        Write-Output "Installing '$appId'..."
        winget install --id $appId

        # Log installation
        Log-InstalledPackages -AppId $appId
    }
}

# Main script logic
if ($args -contains "-Help") {
    Show-Help
} else {
    Winget-SearchAndInstall -SearchTerm $SearchTerm
}