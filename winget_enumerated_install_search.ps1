<#
.SYNOPSIS
A script to perform application searches using Winget, enumerate results, and install applications by selection.

.DESCRIPTION
This script allows the user to search for applications using Winget, displays the results with an enumeration, and
installs the selected application based on the user's choice. The script is interactive and helps streamline the process
of finding and installing applications from the Winget repository.

.PARAMETER SearchTerm
The term to search for in the Winget repository. The script uses this term to find matching applications.

.EXAMPLE
PS> .\WingetSearchInstaller.ps1 -SearchTerm "notepad"

Searches for applications related to "notepad," lists the results, and allows the user to install one of the matches.

.EXAMPLE
PS> .\WingetSearchInstaller.ps1

Prompts the user to input a search term, displays matching results, and allows selection for installation.

.NOTES
Author: Epineph
Date: 2024-12-27
Requires: Windows Package Manager (winget)
#>

param (
    [string]$SearchTerm
)

function Show-Help {
    Get-Help -Name $MyInvocation.MyCommand.Name -Full
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

    # Parse results and remove header lines
    $lines = $searchResults -split "`r?`n"
    $headerIndex = $lines | ForEach-Object { $_ -match "^Name\s+Id\s+Version" } | Where-Object { $_ } | Select-Object -First 1

    if (-not $headerIndex) {
        Write-Output "No valid entries found for '$SearchTerm'."
        return
    }

    $results = $lines | Select-Object -Skip ($lines.IndexOf($headerIndex) + 2) | Where-Object { $_ -match "\S" }

    if (-not $results) {
        Write-Output "No valid entries found for '$SearchTerm'."
        return
    }

    $results | ForEach-Object -Begin { $i = 0 } -Process {
        Write-Output "[$i] $_"
        $i++
    }

    $selectedIndexes = Read-Host "Enter the numbers of the applications to install (comma-separated, or 'q' to quit)"

    if ($selectedIndexes -eq 'q') {
        Write-Output "Exiting the script."
        return
    }

    $indexes = $selectedIndexes -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -match "^\d+$" }

    foreach ($index in $indexes) {
        if ($index -lt 0 -or $index -ge $results.Count) {
            Write-Output "Invalid selection: $index. Skipping."
            continue
        }

        $selectedApp = $results[$index]
        $appId = ($selectedApp -split "\s{2,}")[1]

        Write-Output "Installing '$appId'..."
        winget install --id $appId
    }
}

# Main script logic
if ($args -contains "-Help") {
    Show-Help
} else {
    Winget-SearchAndInstall -SearchTerm $SearchTerm
}
