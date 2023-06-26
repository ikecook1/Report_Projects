# Set the Git repository path
$repositoryPath = "C:\path\to\git\repository"

# Set the desired tag pattern
$tagPattern = "*-production-release-regular"

# Set the destination folder for copied files
$destinationFolder = "C:\path\to\destination\folder"

# Set the extension of files to be removed
$oldFileExtension = "_old.extension"

# Set the path for the execution log file
$logFilePath = "C:\path\to\log\file.log"

try {
    # Verify if Git is installed
    $gitPath = "C:\path\to\git\executable\git.exe"
    if (!(Test-Path $gitPath)) {
        # Write the error message and timestamp to the log file
        $errorMessage = "Git is not installed or not accessible. Please make sure Git is installed and accessible in the specified path: $gitPath"
        Write-Output "ERROR: $errorMessage"
        "An error occurred at $(Get-Date): $errorMessage" | Out-File -FilePath $logFilePath -Append
        exit
    }

    # Change to the Git repository directory
    Set-Location $repositoryPath -ErrorAction Stop

    # Update the local repository with the latest changes
    & $gitPath pull origin master

    # Get the latest tag that matches the specified pattern
    $latestTag = (& $gitPath describe --tags --match $tagPattern --abbrev=0)

    if ([string]::IsNullOrWhiteSpace($latestTag)) {
        # Write the error message and timestamp to the log file
        $errorMessage = "No matching tags found for the pattern: $tagPattern"
        Write-Output "ERROR: $errorMessage"
        "An error occurred at $(Get-Date): $errorMessage" | Out-File -FilePath $logFilePath -Append
        exit
    }

    # Checkout the latest tag
    & $gitPath checkout $latestTag

    # Get the list of changed files
    $changedFiles = (& $gitPath diff-tree -r --no-commit-id --name-only --diff-filter=ACMRT HEAD) | Where-Object { $_ -like "content/*" }

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
            $oldFiles = Get-ChildItem -Path $destinationFolder -File | Where-Object { $_.Name -like "*$($file -replace [regex]::Escape($oldFileExtension), '')"
