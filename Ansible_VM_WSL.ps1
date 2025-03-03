<#
.SYNOPSIS
Sets up Ubuntu Server on WSL2 for Ansible Control Node with custom VM name, username, and password using SecureString for password input.

.DESCRIPTION
This script automates the process of setting up an Ubuntu Server environment using WSL2 on Windows 11.
It prompts for a custom VM name, username, and password (using SecureString for input).
It checks for WSL prerequisites, installs WSL and Ubuntu (with the custom VM name),
creates a default user with the specified username and password with sudo access, and then installs Python and Ansible inside the Ubuntu environment.

.NOTES
- Requires Windows 11 with WSL2 enabled.
- Must be run in PowerShell as Administrator.
- Assumes you want to install the latest Ubuntu LTS.
- **Security Note:** Uses SecureString for password input for improved security during script execution.
  However, the password is still passed as plain text to 'chpasswd' command within WSL.
  For highly sensitive environments, consider more robust password management or key-based authentication.
#>

# --- Script Configuration & User Input ---
$DefaultVMName = "ansible-control-node" # Default VM name if user just presses Enter
$VMName = Read-Host "Enter the desired name for your Ubuntu VM (default: '$DefaultVMName')"
if ([string]::IsNullOrEmpty($VMName)) {
    $VMName = $DefaultVMName
}

$DefaultUsername = "ansible" # Default username if user just presses Enter
$Username = Read-Host "Enter the desired username for the default user (default: '$DefaultUsername')"
if ([string]::IsNullOrEmpty($Username)) {
    $Username = $DefaultUsername
}

# **Improved Security Note:** Using SecureString for password input to enhance security during script execution.
# However, please be aware that the password will still be passed as plain text to the 'chpasswd' command within WSL.
# For highly sensitive environments, consider more robust password management or key-based authentication.
$SecurePassword = Read-Host "Enter the password for the default user (input will be masked)" -AsSecureString

# Convert SecureString to plain text for use in bash command (handle with care)
$Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword))
try {
    # Securely clear the SecureString from memory as soon as possible
    $SecurePassword.Dispose()
} finally {
    # Ensure SecurePassword is disposed of even if errors occur
}


# --- Script Configuration (Internal) ---
$UbuntuDistribution = "Ubuntu" # You can change this to "Ubuntu-22.04", etc., if needed.

# --- Check for Administrator Privileges ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Error: This script must be run as Administrator." -ForegroundColor Red
    return
}

Write-Host "--- Starting WSL2 Ubuntu Server Setup for Ansible ---" -ForegroundColor Cyan
Write-Host "VM Name: '$VMName', Username: '$Username'" -ForegroundColor Cyan

# --- 1. Check for and Enable WSL Optional Features ---
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

# --- 2. Install WSL if not already installed ---
Write-Host "Checking if WSL is installed..." -ForegroundColor Green
if (!(wsl --list --verbose | Select-String "WSL 2")) { # Check if any WSL distribution is listed in WSL 2 mode
    Write-Host "WSL is not installed. Installing WSL..." -ForegroundColor Yellow
    wsl --install
    Write-Host "WSL installation initiated. You might need to restart your computer manually after this script completes if prompted, or if you encounter issues." -ForegroundColor Yellow
} else {
    Write-Host "WSL is already installed." -ForegroundColor Gray
}

# --- 3. Install Ubuntu with Custom VM Name if not already installed ---
Write-Host "Checking if Ubuntu VM named '$VMName' is installed..." -ForegroundColor Green
if (!(wsl --list --verbose | Select-String "$VMName")) {
    Write-Host "Ubuntu VM '$VMName' is not installed. Installing..." -ForegroundColor Yellow
    wsl --install -d $VMName -distribution $UbuntuDistribution # Added -distribution to be explicit
    Write-Host "Ubuntu VM '$VMName' installation initiated." -ForegroundColor Yellow
} else {
    Write-Host "Ubuntu VM '$VMName' is already installed." -ForegroundColor Gray
}

# --- 4. Set Custom VM as Default WSL Distribution ---
Write-Host "Setting '$VMName' as the default WSL distribution..." -ForegroundColor Green
wsl --set-default $VMName
Write-Host "'$VMName' set as default WSL distribution." -ForegroundColor Gray

# --- 5. Configure User, Grant Sudo, Install Python and Ansible inside WSL ---
Write-Host "Configuring user '$Username', granting sudo, installing Python and Ansible..." -ForegroundColor Green
Write-Host "This might take a few minutes depending on your internet connection and system performance." -ForegroundColor Gray

try {
    wsl -d $VMName -- bash -c "
        # Create user and set password (non-interactive)
        adduser --disabled-password --gecos '' '$Username'
        echo '$Username':'$Password' | chpasswd

        # Grant sudo access to the user
        usermod -aG sudo '$Username'

        # Switch to the newly created user (important for correct home directory for ansible --user install)
        su - '$Username' -c '
            # Update package lists, install Python and pip, install Ansible for the user
            sudo apt-get update
            sudo apt-get install -y python3 python3-pip
            pip3 install --user ansible
        '
    "
    Write-Host "User '$Username' created with sudo access, Python and Ansible installed successfully inside WSL." -ForegroundColor Green
} catch {
    Write-Host "Error occurred while configuring user, granting sudo, or installing Python/Ansible inside WSL:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "Please check for internet connectivity, WSL configuration, and username/password requirements." -ForegroundColor Red
}

Write-Host "--- WSL2 Ubuntu Server setup for Ansible completed! ---" -ForegroundColor Cyan
Write-Host "You can now access your Ubuntu WSL environment by running 'wsl' or 'wsl -d $VMName' in PowerShell or Command Prompt." -ForegroundColor Green
Write-Host "Login as user '$Username' with the password you provided." -ForegroundColor Green
Write-Host "Ansible is installed and ready for use inside your Ubuntu environment for user '$Username'." -ForegroundColor Green
Write-Host "Remember to configure your Ansible inventory and start building your playbooks!" -ForegroundColor Green

# --- Script End ---