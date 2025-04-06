Write-Host "***************************************************************" -ForegroundColor Yellow
Write-Host " WSL VM Setup Script " -ForegroundColor Yellow
Write-Host "***************************************************************" -ForegroundColor Yellow

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Error: This script must be run as Administrator." -ForegroundColor Red
    return
}

Write-Host "Checking if WSL optional features are enabled..." -ForegroundColor Green
$VMPlatformFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
$WSLFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

if (-not $VMPlatformFeature.State -or $VMPlatformFeature.State -ne "Enabled") {
    Write-Host "Virtual Machine Platform feature is not enabled. Enabling..." -ForegroundColor Yellow
    Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
} else {
    Write-Host "Virtual Machine Platform feature is already enabled." -ForegroundColor Gray
}

if (-not $WSLFeature.State -or $WSLFeature.State -ne "Enabled") {
    Write-Host "Windows Subsystem for Linux feature is not enabled. Enabling..." -ForegroundColor Yellow
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
} else {
    Write-Host "Windows Subsystem for Linux feature is already enabled." -ForegroundColor Gray
}

Write-Host ""
Write-Host "Checking WSL install status..." -ForegroundColor Yellow
Write-Host ""

# Check if WSL is installed
if (!(Get-Command wsl -ErrorAction SilentlyContinue)) {
    Write-Host "WSL is not installed. Installing WSL..." -ForegroundColor Red
    wsl --install
    Write-Host "WSL installation initiated. You might need to restart your computer manually after this script completes if prompted, or if you encounter issues." -ForegroundColor Red
}
else {
    Write-Host "WSL is already installed. Continuing..." -ForegroundColor Green
}

Write-Host ""
Write-Host "Fetching available distributions from the online list..." -ForegroundColor Cyan
Write-Host ""

$onlineListRaw = wsl --list --online
if (-not $onlineListRaw) {
    Write-Host "Unable to retrieve online distributions." -ForegroundColor Red
    return
}
$onlineDistroLines = $onlineListRaw | Select-Object -Skip 8 | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
if ($onlineDistroLines.Count -eq 0) {
    Write-Host "No online distributions were found." -ForegroundColor Red
    return
}
$distroOptions = @()
foreach ($line in $onlineDistroLines) {
    # Split line by whitespace.
    $tokens = $line -split "\s+"
    # Sometimes an asterisk indicates the default distro; ignore it.
    if ($tokens[0] -eq "*") {
        $distroName = $tokens[1]
    }
    else {
        $distroName = $tokens[0]
    }
    $distroOptions += $distroName
}
Write-Host "Available Operating Systems for WSL:" -ForegroundColor Cyan
for ($i = 0; $i -lt $distroOptions.Count; $i++) {
    Write-Host "$($i+1). $($distroOptions[$i])" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Enter the name of the OS you want to install (Press Ctrl+C to exit): " -ForegroundColor Yellow

$selectedOS = Read-Host

Write-Host ""
Write-Host "You selected: $selectedOS" -ForegroundColor Green

$default_name = "control-node" # Default VM name if user just presses Enter
Write-Host ""
Write-Host "Enter the name for your $selectedOS VM, or press Enter to use the default name ($default_name) (Press Ctrl+C to exit): " -ForegroundColor Yellow

$vmName = Read-Host
if ([string]::IsNullOrEmpty($vmName)) {
    $vmName = $default_name
}

if (!(wsl --list --verbose | Select-String "$vmName")) {
    Write-Host ""
    Write-Host "Creating WSL2 VM with distribution: " -ForegroundColor Yellow -NoNewline
    Write-Host $selectedOS -ForegroundColor Green -NoNewline
    Write-Host " and name: " -ForegroundColor Yellow -NoNewline
    Write-Host $vmName -ForegroundColor Green
    Write-Host ""
    wsl --install --distribution "$selectedOS" --name "$vmName"
} else {
    Write-Host "WSL2 VM '$vmName' is already installed." -ForegroundColor Gray
}

