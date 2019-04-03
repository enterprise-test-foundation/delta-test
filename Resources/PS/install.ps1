﻿####################################################################
#
# DELTATEST v2.0.0
#
# Installation Script
#
# To install deltaTest manually, navigate to the shared deltaTest
# repository and double-click the +INSTALL shortcut. This will place
# a local_config.psd1 file, which you can override to change shared
# configs in the local context.
#
# If you run this script directly using the parameters defined 
# below, the same process will occur, but the config files will be
# placed and shared configs overridden as specified.
# 
####################################################################
#
# Copyright 2016-2019 by the following contributors:
#
#   Continuus Technologies, LLC
#   Enterprise Data Foundation, Inc.
#   HexisData, Inc.
#   HotQuant, Inc. 
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# version 2 as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
####################################################################

param(
    [string]$LocalDir = "C:\deltaTest",
    [string]$NoInput,
    [string]$ActiveEnvironment,
    [string]$MedmProcessAgentPath
)

# ELEVATE SCRIPT IF NECESSARY.

# Get the ID and security principal of the current user account
$myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal = new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
 
# Get the security principal for the Administrator role
$adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator
 
# If we are currently running as Administrator...
if ($myWindowsPrincipal.IsInRole($adminRole))
{
    # ... then change the title & background color.
    $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + " (Elevated)"
    $Host.UI.RawUI.BackgroundColor = "DarkBlue"
    clear-host
}

else
{
    # ... otherwise relaunch as administrator.
    $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";
    $newProcess.Arguments = $myInvocation.MyCommand.Definition;

    if ($LocalDir) { $newProcess.Arguments += " -LocalDir '$LocalDir'" }
    if ($NoInput) { $newProcess.Arguments += " -NoInput `$$NoInput" }
    if ($ActiveEnvironment) { $newProcess.Arguments += " -ActiveEnvironment '$ActiveEnvironment'" } 
    if ($MedmProcessAgentPath) { $newProcess.Arguments += " -MedmProcessAgentPath '$MedmProcessAgentPath'" } 

    $newProcess.Verb = "runas";
    [System.Diagnostics.Process]::Start($newProcess);
   
    # Exit from the current, unelevated, process
    exit
}

# BEGIN
Write-Host "`nThank you for installing deltaTest v2.0.0!"

# Create environment variables.
Write-Host "`nCreating %deltaTest% environment variable..." -NoNewline
[Environment]::SetEnvironmentVariable('deltaTest', $LocalDir, 'Machine')
Write-Host "Done!"

Write-Host "Creating %deltaTestShared% environment variable..." -NoNewline
[Environment]::SetEnvironmentVariable('deltaTestShared', $($PSScriptRoot | Split-Path -Parent | Split-Path -Parent), 'Machine')
Write-Host "Done!"

# Validate & hydrate params.
$SharedConfig = Import-LocalizedData -BaseDirectory $env:deltaTestShared -FileName 'shared_config.psd1'

if (!$NoInput) { $NoInput = $SharedConfig.NoInput }
if (!$ActiveEnvironment) { $ActiveEnvironment = $SharedConfig.ActiveEnvironment }
if (!$MedmProcessAgentPath) { $MedmProcessAgentPath = $SharedConfig.MedmProcessAgentPath }

# Check PS Version
Write-Host "`nChecking PowerShell version..."
Write-Host "Current PowerShell version: $($PSVersionTable.PSVersion.ToString())"

$MinPSVersion = 5
If ($PSVersionTable.PSVersion.Major -ge $MinPSVersion) {
    Write-Host "No change required."
}
Else {
	Write-Host "ERROR: deltaTest requires Powershell version $MinPSVersion or better!" -ForegroundColor Yellow
	[void](Read-Host "`nPress Enter to exit")
	Exit
}	

# Check execution policy.
Write-Host "`nChecking execution policy..."
$CurrentExecutionPolicy = (Get-ExecutionPolicy).ToString()
Write-Host "Current Execution Policy: $CurrentExecutionPolicy"

If (("Unrestricted", "Bypass").Contains($CurrentExecutionPolicy)) {
    Write-Host "No change required."
}
Else {
    Write-Host "Setting Execution Policy to Unrestricted... " -NoNewline
    Set-ExecutionPolicy Unrestricted -Force
    Write-Host "Done!"
}

# Check SqlServer module.
Write-Host "`nChecking SqlServer module..."

If (Get-Module -ListAvailable -Name "SqlServer") {
    Write-Host "SqlServer module is already installed!"
}
Else {
    Write-Host "Installing SqlServer module... " -NoNewline 
    Install-Module -Name SqlServer -Force
    Write-Host "Done!"
}

# Check WinMerge installation.
function Test-Installed( $program ) {
    
    $x86 = ((Get-ChildItem 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall') |
        Where-Object { $_.GetValue('DisplayName') -like "*$program*" } ).Length -gt 0;

    $x64 = ((Get-ChildItem "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall") |
        Where-Object { $_.GetValue('DisplayName') -like "*$program*" } ).Length -gt 0;

    return $x86 -or $x64;
}

If (!$NoInput) {
    Write-Host "`nChecking WinMerge installation..."

    If (Test-Installed 'WinMerge') {
        Write-Host 'WinMerge is already installed!'
    }
    Else {
        Write-Host 'Installing WinMerge... ' -NoNewline 
        $WinMergeInstallerPath = "$($PSScriptRoot | Split-Path -Parent)\WinMerge-2.14.0-Setup.exe"
        $WinMergeInstallerParams = '/SILENT' # http://www.jrsoftware.org/ishelp/index.php?topic=setupcmdline
        & $WinMergeInstallerPath $WinMergeInstallerParams | Write-Host
        Write-Host 'Done!'
    }
}

# Import deltaTest module.
Import-Module "$env:deltaTestShared\Resources\PS\deltaTest.psm1" -Force

# Write local config file. 
Write-Host "`nWriting local config file..."

# Create local config directory if it doesn't exist.
if (!(Test-Path $env:deltaTest -PathType Container)) { New-Item $env:deltaTest -ItemType "directory" }

# If there is an existing local config file...
if ((Test-Path "$env:deltaTest\local_config.psd1" -PathType Leaf) -and ((Read-UserEntry -Label 'LOCAL CONFIG FILE ALREADY EXISTS. PRESERVE DATA?' -Default 'Y' -Pattern 'y|n') -eq 'y')) { 
    # Load local config.
    $LocalConfig = Import-LocalizedData -BaseDirectory $env:deltaTest -FileName "local_config.psd1"

    # Override params with local config.
    $params = @{
        NoInput = $LocalConfig.NoInput
        ActiveEnvironment = $LocalConfig.ActiveEnvironment
        MedmProcessAgentPath = $LocalConfig.MedmProcessAgentPath
        TextDiffExe = $LocalConfig.TextDiffExe
        TextDiffParams = $LocalConfig.TextDiffParams
    }

    # Write new local config file.
    & "$env:deltaTestShared\Resources\PS\local.ps1" @params
}

# ... otherwise just overwrite local config file with new defaults.
else { & "$env:deltaTestShared\Resources\PS\local.ps1" }

Write-Host "`nDone!"

# Copy init script.
Copy-Item -Path "$env:deltaTestShared\Resources\PS\init.ps1" -Destination "$env:deltaTest\init.ps1"

# Clear config variable so next init reloads it.
$Global:deltaTestConfig = $null

# END
Write-Host "`nLocal deltaTest installation complete!"
[void](Read-Host "`nPress Enter to exit")

