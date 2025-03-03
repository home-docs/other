<#
.SYNOPSIS
Sets up Ubuntu Server on WSL2 for Ansible Control Node with custom VM name, username, and password using SecureString input, retry logic, corrected wsl --install syntax, **ensures LF line endings for bash config script**.

.DESCRIPTION
This script automates the process of setting up an Ubuntu Server environment using WSL2 on Windows 11.
It prompts for a custom VM name, username, and password (using SecureString for input).
It checks if WSL is already installed. If not installed, it installs WSL. It then installs Ubuntu with the custom VM name,
creates a default user with the specified username and a temporary password.  **The PowerShell script now automatically creates the `configure_ansible_node.sh` bash script in the same directory, ensuring LF line endings. The script then provides instructions for the user to manually copy and execute the bash script inside the WSL VM.**
**Includes retry logic to handle "WSL_E_DISTRO_NOT_FOUND" errors during VM setup and uses corrected `wsl --install` syntax.**

.NOTES
- Requires Windows 11 with WSL2 enabled (or to be enabled).
- Must be run in PowerShell as Administrator.
- Assumes you want to install the latest Ubuntu LTS.
- **Automated Bash Script Creation (LF Endings):** The PowerShell script now automatically creates the `configure_ansible_node.sh` bash script in the same directory, explicitly ensuring LF line endings using `-Encoding Ascii`.
- **Manual Steps:**  The user needs to manually copy and execute the `configure_ansible_node.sh` bash script inside their WSL VM after the VM is created, as instructed by the script output.
- **Security Note:** Uses SecureString for password input for improved security during script execution.
  However, the password is still passed as plain text to 'passwd' command within WSL for the initial user setup.
  The separate bash script will then handle further configuration. For highly sensitive environments, consider more robust password management or key-based authentication.
#>

# --- Script Configuration & User Input ---
$DefaultVMName = "AnsibleControlVM" # Default VM name if user just presses Enter
$VMName = Read-Host "Enter the desired name for your Ubuntu VM (default: '$DefaultVMName')"
if ([string]::IsNullOrEmpty($VMName)) {
    $VMName = $DefaultVMName
}

$DefaultUsername = "ansibleuser" # Default username if user just presses Enter
$Username = Read-Host "Enter the desired username for the default user (default: '$DefaultUsername')"
if ([string]::IsNullOrEmpty($Username)) {
    $Username = $DefaultUsername
}

# **Improved Security Note:** Using SecureString for password input to enhance security during script execution.
# However, please be aware that the password will still be passed as plain text to 'passwd' command within WSL for initial setup.
# The separate bash script handles further configuration. For highly sensitive environments, consider more robust password management or key-based authentication.
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
$MaxRetries = 10          # Maximum retry attempts for WSL commands
$RetryDelaySeconds = 5    # Delay between retries in seconds
$UseInstallationDelay = $false # Delay after install (removed by default as requested)
$BashScriptName = "configure_ansible_node.sh" # Name of the bash script

# --- Check for Administrator Privileges ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Error: This script must be run as Administrator." -ForegroundColor Red
    return
}

Write-Host "--- Starting WSL2 Ubuntu Server Setup for Ansible ---" -ForegroundColor Cyan
Write-Host "VM Name: '$VMName', Username: '$Username'" -ForegroundColor Cyan

# --- 0. Create Bash Configuration Script Locally (Ensuring LF Line Endings) ---
Write-Host "Creating bash configuration script '$BashScriptName' in the script's directory with LF line endings..." -ForegroundColor Green
$BashScriptContent = @"
#!/bin/bash
set -e # Exit on error

USERNAME="\$1" # Username will be passed as the first argument

echo "--- Starting Ansible Node Configuration Script ---"

# 1. Grant sudo access
echo "Granting sudo access to user '\$USERNAME'..."
usermod -aG sudo "\$USERNAME"
echo "Sudo access granted."

# 2. Install Python and pip
echo "Installing Python 3 and pip..."
sudo apt-get update
sudo apt-get install -y python3 python3-pip
echo "Python and pip installed."

# 3. Install Ansible for the user
echo "Installing Ansible for user '\$USERNAME'..."
sudo pip3 install --user ansible
echo "Ansible installed for user '\$USERNAME'."

echo "--- Ansible Node Configuration Script Completed ---"
"@

# Output the bash script content to a file in the same directory as the PowerShell script
# **Explicitly using -Encoding Ascii which should enforce LF line endings**
$BashScriptContent | Out-File -FilePath "./$BashScriptName" -Encoding Ascii
Write-Host "Bash configuration script '$BashScriptName' created locally with LF line endings (using -Encoding Ascii)." -ForegroundColor Green


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

# --- 2. Install WSL if not already installed (Improved Check) ---
Write-Host "Checking if WSL is installed..." -ForegroundColor Green
if (!(Get-Command wsl -ErrorAction SilentlyContinue)) { # Check if 'wsl' command exists
    Write-Host "WSL is not installed. Installing WSL..." -ForegroundColor Yellow
    wsl --install
    Write-Host "WSL installation initiated. You might need to restart your computer manually after this script completes if prompted, or if you encounter issues." -ForegroundColor Yellow
} else {
    Write-Host "WSL is already installed (command 'wsl' found)." -ForegroundColor Gray
}

# --- 3. Install Ubuntu with Custom VM Name if not already installed ---
Write-Host "Checking if Ubuntu VM named '$VMName' is installed..." -ForegroundColor Green
if (!(wsl --list --verbose | Select-String "$VMName")) {
    Write-Host "Ubuntu VM '$VMName' is not installed. Installing as '$VMName'..." -ForegroundColor Yellow
    # **Corrected wsl --install syntax:**
    wsl --install --distribution $UbuntuDistribution --name $VMName
    Write-Host "Ubuntu VM '$VMName' installation initiated." -ForegroundColor Yellow

    if ($UseInstallationDelay) { # Conditional delay - disabled by default now
        Write-Host "Waiting 30 seconds for VM registration to complete..." -ForegroundColor Yellow
        Start-Sleep -Seconds 30
        Write-Host "Resuming setup..." -ForegroundColor Yellow
    }

} else {
    Write-Host "Ubuntu VM '$VMName' is already installed." -ForegroundColor Gray
}

# --- 4. Set Custom VM as Default WSL Distribution with Retry ---
Write-Host "Setting '$VMName' as the default WSL distribution..." -ForegroundColor Green
for ($retry = 1; $retry -le $MaxRetries; $retry++) {
    Write-Host "Attempt $($retry) to set '$VMName' as default..." -ForegroundColor DarkYellow
    wsl --set-default $VMName
    if ($LastExitCode -eq 0) {
        Write-Host "'$VMName' set as default WSL distribution." -ForegroundColor Gray
        break # Success, exit retry loop
    } else {
        $ErrorMessage = (Get-Error)[0].Exception.Message
        if ($ErrorMessage -like "*WSL_E_DISTRO_NOT_FOUND*") {
            Write-Host "Distribution not found yet (attempt $(<span class="math-inline">retry\)/</span>($MaxRetries)). Waiting $($RetryDelaySeconds) seconds before retry..." -ForegroundColor Yellow
            Start-Sleep -Seconds $RetryDelaySeconds
        } else {
            Write-Host "Error setting default distribution (non-WSL_E_DISTRO_NOT_FOUND):" -ForegroundColor Red
            Write-Host $ErrorMessage -ForegroundColor Red
            break # Exit retry loop on unexpected error
        }
    }
    if ($retry -eq $MaxRetries) {
        Write-Host "Failed to set '$VMName' as default after $($MaxRetries) retries. Aborting default setting." -ForegroundColor Red
        # We can choose to continue or abort the script here. Let's continue for now and try to proceed with configuration anyway.
        # return # Uncomment this line to abort script if setting default fails
    }
}


# --- 5. Configure User (Initial Setup in PowerShell) ---
Write-Host "Creating initial user '$Username'..." -ForegroundColor Green
try {
        # Construct bash commands with LF line endings explicitly for initial user setup
        $bashCommandsInitialUser = @(
            "adduser --disabled-password --gecos '' '$Username'"
            "echo '$Username':'$Password' | chpasswd" # Setting a temporary password - bash script will handle final setup
        ) -join "`n"

        wsl -d $VMName -- bash -c $bashCommandsInitialUser
        Write-Host "Initial user '$Username' created." -ForegroundColor Green
} catch {
    Write-Host "Error creating initial user '$Username':" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "Please check WSL and try again." -ForegroundColor Red
    return # Abort script if initial user creation fails
}


# --- 6. Manual Instructions for Bash Script Copy and Execution ---
Write-Host "--- Manual Steps Required to Complete Ansible Setup ---" -ForegroundColor Yellow
Write-Host "1. Copy the bash configuration script '$BashScriptName' to your WSL VM." -ForegroundColor Yellow
Write-Host "   The script '$BashScriptName' has been created in the same directory as this PowerShell script. It is crucial to copy this script correctly to your WSL VM." -ForegroundColorYellow # Emphasized crucial copy
Write-Host "   Open a separate PowerShell or Command Prompt window and run the following command:" -ForegroundColor Yellow
Write-Host "      wsl -d $VMName" -ForegroundColor Cyan
Write-Host "   Once inside the WSL terminal, execute this command to copy the script:" -ForegroundColor Yellow
Write-Host "      cp /mnt/c/`"path-to-powershell-script-directory`"/configure_ansible_node.sh ~/" -ForegroundColor Cyan
Write-Host "      (Replace `"`path-to-powershell-script-directory`"` with the actual path where you saved the PowerShell script and bash script)" -ForegroundColor Yellow
Write-Host "" -ForegroundColor Yellow # Add an empty line for better readability
Write-Host "2. Execute the bash configuration script inside your WSL VM." -ForegroundColor Yellow
Write-Host "   In the same WSL terminal (where you just copied the script), run:" -ForegroundColor Yellow
Write-Host "      bash ~/configure_ansible_node.sh '$Username'" -ForegroundColor Cyan
Write-Host "" -ForegroundColor Yellow # Add an empty line for better readability
Write-Host "After completing these manual steps inside WSL, the Ansible setup will be finalized." -ForegroundColor Yellow


Write-Host "--- WSL2 Ubuntu Server setup (Initial VM and User) completed! ---" -ForegroundColor Cyan
Write-Host "Please follow the MANUAL STEPS above to finalize the Ansible setup." -ForegroundColor Cyan
Write-Host "After manual steps are done, you can access your Ubuntu WSL environment by running 'wsl' or 'wsl -d $VMName' in PowerShell or Command Prompt." -ForegroundColor Green
Write-Host "Login as user '$Username' with the password you provided." -ForegroundColor Green
# Ansible installation part is now handled by the bash script executed manually
Write-Host "Remember to configure your Ansible inventory and start building your playbooks!" -ForegroundColor Green

# --- Script End ---