$WSLVerboseOutputLines = @()

# --- Get and Display Raw WSL Distribution List ---
Write-Host "--- Getting list of installed WSL distributions ---" -ForegroundColor Cyan
Write-Host "The following is the output of 'wsl --list --verbose':" -ForegroundColor Green

try {
    $WSLVerboseOutputLines = wsl --list --verbose
    if ($WSLVerboseOutputLines) {
        foreach ($line in $WSLVerboseOutputLines) {
            Write-Host $line -ForegroundColor Gray # Display each line of the output
        }
    } else {
        Write-Host "No WSL distributions found." -ForegroundColor Yellow
        return
    }
} catch {
    Write-Host "Error getting WSL distribution list:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    return
}

# --- User Input for VM Name ---
Write-Host ""
Write-Host "--- Enter the name of the WSL distribution to remove ---" -ForegroundColor Cyan
Write-Host "Please **carefully copy** the **NAME** of the distribution you want to remove from the list above." -ForegroundColor Yellow
$selectedDistributionName = Read-Host "Enter the WSL distribution name to remove"

# --- Input Validation (Basic - Check for Empty Name) ---
if ([string]::IsNullOrWhiteSpace($selectedDistributionName)) {
    Write-Host "Error: Distribution name cannot be empty. Script cancelled." -ForegroundColor Red
    return
}

# --- EXPLICIT Confirmation of Deletion with DATA LOSS WARNING ---
Write-Host ""
Write-Host "--- **DATA LOSS WARNING! - CONFIRM DELETION** ---" -ForegroundColor Red
Write-Host "**YOU ARE ABOUT TO PERMANENTLY DELETE THE WSL DISTRIBUTION: '$selectedDistributionName'**" -ForegroundColor Red
Write-Host "**ALL FILES AND DATA WITHIN THIS VM WILL BE IRRECOVERABLY LOST!**" -ForegroundColor Red
Write-Host ""
$confirmRemove = Read-Host "To **PERMANENTLY DELETE** this VM and **ALL ITS DATA**, type the word 'DELETE' in uppercase and press Enter. Otherwise, press Enter to cancel"

if ($confirmRemove -ne "DELETE") {
    Write-Host "Removal cancelled by user." -ForegroundColor Green
    return
}

# --- Remove the WSL Distribution ---
Write-Host ""
Write-Host "--- Removing WSL Distribution: '$selectedDistributionName' ---" -ForegroundColor Cyan
try {
    wsl --unregister $selectedDistributionName
    Write-Host "WSL distribution '$selectedDistributionName' has been successfully removed." -ForegroundColor Green
} catch {
    Write-Host "Error removing WSL distribution '$selectedDistributionName':" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Write-Host "--- Script completed ---" -ForegroundColor Cyan

# --- Script End ---