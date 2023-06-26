# Set the Git repository path
$repositoryPath = "C:\Repos1\Edge\z_test"

# Set the desired tag pattern
$tagPattern = "*v1.6.1"

# Set the destination folder for copied files
$destinationFolder = "C:\Repos1\Edge\z_test_output"

# Set the extension of files to be removed
$oldFileExtension = "_old.rdl"

# Set the path for the execution log file
$logFilePath = "C:\Repos1\Edge\z_test_output\file.log"

try {
    # Verify if Git is installed
    $gitPath = "C:\Users\isaac.atuahene\AppData\Local\Programs\Git\cmd\git.exe"
    if (!(Test-Path $gitPath)) {
        # Write the error message and timestamp to the log file
        $errorMessage = "Git is not installed or not accessible. Please make sure Git is installed and accessible in the specified path: $gitPath"
        Write-Output "ERROR: $errorMessage"
        "An error occurred at $(Get-Date): $errorMessage" | Out-File -FilePath $logFilePath -Append
        exit
    }

    # Change to the Git repository directory
    Set-Location $repositoryPath -ErrorAction Stop

    # Get the latest tag that matches the specified pattern
    $latestTag = (& $gitPath tag --list $tagPattern | Sort-Object -Descending | Select-Object -First 1)

    if ([string]::IsNullOrWhiteSpace($latestTag)) {
        # Write the error message and timestamp to the log file
        $errorMessage = "No matching tags found for the pattern: $tagPattern"
        Write-Output "ERROR: $errorMessage"
        "An error occurred at $(Get-Date): $errorMessage" | Out-File -FilePath $logFilePath -Append
        exit
    }

    # Get the commit ID for the parent of the latest tag
    $commitId = (& $gitPath rev-parse $latestTag^)

    # Get the list of changed files
    $changedFiles = (& $gitPath diff-tree -r --no-commit-id --name-only --diff-filter=ACMRT $commitId $latestTag) | Where-Object { $_ -like "content/*" }

    # Print the list of changed files
    Write-Output "Changed files: $($changedFiles -join ', ')"

    # Get the total number of changed files
    $totalFiles = $changedFiles.Count
    $completedFiles = 0

    # Create the destination folder if it doesn't exist
    if (!(Test-Path -Path $destinationFolder)) {
        New-Item -ItemType Directory -Path $destinationFolder | Out-Null
    }

    # Loop through the changed files
    foreach ($file in $changedFiles) {
        # Copy the file to the destination folder
        $sourceFile = Join-Path -Path $repositoryPath -ChildPath $file
        Write-Output "Copying file: $sourceFile to $destinationFolder"
        try {
            Copy-Item -Path $sourceFile -Destination $destinationFolder -ErrorAction Stop
        }
        catch {
            # Write the error message and timestamp to the log file
            $errorMessage = "Error occurred while copying file '$file': $_"
            Write-Output "ERROR: $errorMessage"
            "An error occurred at $(Get-Date): $errorMessage" | Out-File -FilePath $logFilePath -Append
            continue
        }

        # Remove old files ending with "_old.extension"
        if ($file -like "*$oldFileExtension") {
            $oldFiles = Get-ChildItem -Path $destinationFolder -File | Where-Object { $_.Name -like "*$($file -replace [regex]::Escape($oldFileExtension), '')" }
            foreach ($oldFile in $oldFiles) {
                try {
                    Remove-Item -Path $oldFile.FullName -Force -ErrorAction Stop
                }
                catch {
                    # Write the error message and timestamp to the log file
                    $errorMessage = "Error occurred while removing file '$($oldFile.FullName)': $_"
                    Write-Output "ERROR: $errorMessage"
                    "An error occurred at $(Get-Date): $errorMessage" | Out-File -FilePath $logFilePath -Append
                    continue
                }
            }
        }

        # Increment the completed files counter
        $completedFiles++

        # Update the progress bar
        $percentComplete = ($completedFiles / $totalFiles) * 100
        Write-Progress -Activity "Processing Files" -Status "Copying files..." -PercentComplete $percentComplete
    }

    # Update the progress bar once after processing all files
    Write-Progress -Activity "Processing Files" -Status "Copying files..." -Completed -PercentComplete 100
}
catch {
    # Handle any additional errors here
    $errorMessage = "An unexpected error occurred: $_"
    Write-Output "ERROR: $errorMessage"
    "An error occurred at $(Get-Date): $errorMessage" | Out-File -FilePath $logFilePath -Append
}
