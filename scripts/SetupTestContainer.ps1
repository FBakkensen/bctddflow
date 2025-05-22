<#
.SYNOPSIS
    Sets up a Business Central test container.
.DESCRIPTION
    This script creates a new Business Central container with test toolkit and performance toolkit.
    It uses settings from the TDDConfig.psd1 file by default, but parameters can override these settings.
    
    The script uses the centralized configuration management through Get-TDDConfiguration.ps1
    to load and validate configuration settings.
.PARAMETER ContainerName
    The name of the Business Central container to create. Default is from configuration or 'bctest'.
.PARAMETER ImageName
    The Business Central Docker image to use. If not provided, latest sandbox artifact will be used.
.PARAMETER Auth
    Authentication method for the container. Default is from configuration or 'NavUserPassword'.
    Valid values are "Windows", "UserPassword", and "NavUserPassword".
.PARAMETER Password
    Password for the admin user as a SecureString. If not provided, a default password will be used. Ignored if Credential parameter is provided.
.PARAMETER Credential
    PSCredential object for the container admin user. If provided, this takes precedence over the Password parameter.
.PARAMETER MemoryLimit
    Memory limit for the container. Default is from configuration or '8G'.
.PARAMETER Accept_Eula
    Whether to accept the EULA. Default is from configuration or $true.
.PARAMETER Accept_Outdated
    Whether to accept outdated images. Default is from configuration or $true.
.PARAMETER ConfigPath
    Path to the configuration file. Default is "scripts\TDDConfig.psd1" in the same directory as this script.
    This path is passed to Get-TDDConfiguration.ps1 for loading the configuration.
.PARAMETER Country
    Country version for the Business Central container. Default is from configuration or 'w1'.
.PARAMETER IncludeTestToolkit
    Whether to include the test toolkit. Default is from configuration or $true.
.PARAMETER IncludePerformanceToolkit
    Whether to include the performance toolkit. Default is from configuration or $true.
.PARAMETER AssignPremiumPlan
    Whether to assign the premium plan. Default is from configuration or $true.
.EXAMPLE
    .\SetupTestContainer.ps1
    # Uses settings from the default configuration file loaded through Get-TDDConfiguration.ps1
.EXAMPLE
    .\SetupTestContainer.ps1 -ContainerName "mytest" -Auth "Windows"
    # Overrides configuration settings with provided parameters
.EXAMPLE
    .\SetupTestContainer.ps1 -ConfigPath "C:\MyProject\CustomConfig.psd1"
    # Uses a custom configuration file through Get-TDDConfiguration.ps1
.NOTES
    This script is part of the Business Central TDD workflow.
    It uses the centralized configuration management through Get-TDDConfiguration.ps1.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ContainerName,

    [Parameter(Mandatory = $false)]
    [string]$ImageName,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Windows", "UserPassword", "NavUserPassword")]
    [string]$Auth,

    [Parameter(Mandatory = $false)]
    [System.Security.SecureString]$Password,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Mandatory = $false)]
    [string]$MemoryLimit,

    [Parameter(Mandatory = $false)]
    [bool]$Accept_Eula,

    [Parameter(Mandatory = $false)]
    [bool]$Accept_Outdated,

    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath "TDDConfig.psd1"),

    [Parameter(Mandatory = $false)]
    [string]$Country,

    [Parameter(Mandatory = $false)]
    [bool]$IncludeTestToolkit,

    [Parameter(Mandatory = $false)]
    [bool]$IncludePerformanceToolkit,

    [Parameter(Mandatory = $false)]
    [bool]$AssignPremiumPlan
)

# Function to display info messages
function Write-InfoMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "INFO: $Message" -ForegroundColor Cyan
}

# Function to display success messages
function Write-SuccessMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "SUCCESS: $Message" -ForegroundColor Green
}

# Import the Get-TDDConfiguration script
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Parent $scriptPath
$getTDDConfigPath = Join-Path -Path $scriptDir -ChildPath "Get-TDDConfiguration.ps1"

# Check if the Get-TDDConfiguration script exists
if (-not (Test-Path -Path $getTDDConfigPath)) {
    Write-Host "ERROR: Get-TDDConfiguration.ps1 script not found at $getTDDConfigPath" -ForegroundColor Red
    exit 1
}

# Fail fast on any terminating / non-terminating error
$ErrorActionPreference = 'Stop'
$VerbosePreference     = 'Continue'
$InformationPreference = 'Continue'

# Load configuration using Get-TDDConfiguration
$config = & $getTDDConfigPath -ConfigPath $ConfigPath

# Check if configuration was loaded successfully
if ($null -eq $config) {
    Write-Host "ERROR: Failed to load configuration. Please check the configuration file and try again." -ForegroundColor Red
    exit 1
}

Write-InfoMessage "Configuration loaded successfully from Get-TDDConfiguration."

# Apply configuration values if parameters are not explicitly provided
if (-not $PSBoundParameters.ContainsKey('ContainerName')) {
    $ContainerName = $config.ContainerName
}

if (-not $PSBoundParameters.ContainsKey('Auth')) {
    $Auth = $config.Auth
}

if (-not $PSBoundParameters.ContainsKey('MemoryLimit')) {
    $MemoryLimit = $config.MemoryLimit
}

if (-not $PSBoundParameters.ContainsKey('Accept_Eula')) {
    $Accept_Eula = $config.Accept_Eula
}

if (-not $PSBoundParameters.ContainsKey('Accept_Outdated')) {
    $Accept_Outdated = $config.Accept_Outdated
}

if (-not $PSBoundParameters.ContainsKey('Country')) {
    $Country = $config.Country
}

if (-not $PSBoundParameters.ContainsKey('IncludeTestToolkit')) {
    $IncludeTestToolkit = $config.IncludeTestToolkit
}

if (-not $PSBoundParameters.ContainsKey('IncludePerformanceToolkit')) {
    $IncludePerformanceToolkit = $config.IncludePerformanceToolkit
}

if (-not $PSBoundParameters.ContainsKey('AssignPremiumPlan')) {
    $AssignPremiumPlan = $config.AssignPremiumPlan
}

# Define the user module path for BcContainerHelper
$userModulePath = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath "PowerShell\Modules\BcContainerHelper"

# Function to check if BcContainerHelper is available and import it if possible
function Import-BcContainerHelperIfAvailable {
    [CmdletBinding()]
    param()

    # Check if module is already imported
    if (Get-Module -Name BcContainerHelper) {
        return $true
    }

    # Check if module is available in the user's module path
    if (Test-Path -Path $userModulePath) {
        try {
            # Find the latest version folder
            $latestVersion = Get-ChildItem -Path $userModulePath -Directory |
                             Sort-Object -Property Name -Descending |
                             Select-Object -First 1

            if ($latestVersion) {
                $modulePath = Join-Path -Path $latestVersion.FullName -ChildPath "BcContainerHelper.psd1"
                if (Test-Path -Path $modulePath) {
                    Import-Module $modulePath -Force
                    return $true
                }
            }
        }
        catch {
            Write-Host "Error importing BcContainerHelper from user module path: $_" -ForegroundColor Yellow
        }
    }

    # Try to import from any available location
    try {
        Import-Module BcContainerHelper -ErrorAction SilentlyContinue
        if (Get-Module -Name BcContainerHelper) {
            return $true
        }
    }
    catch {
        # Module not available
    }

    return $false
}

# Ensure BcContainerHelper is available
$bcContainerHelperAvailable = Import-BcContainerHelperIfAvailable
if (-not $bcContainerHelperAvailable) {
    Write-Host "ERROR: BcContainerHelper module is not installed or cannot be imported." -ForegroundColor Red
    Write-Host "Please install the module by running: Install-Module BcContainerHelper -Force" -ForegroundColor Yellow
    exit 1
}

Write-InfoMessage "Setting up Business Central test container '$ContainerName'..."

# Create secure credential
if ($PSBoundParameters.ContainsKey('Credential')) {
    # Use the provided credential
    $credential = $Credential
    Write-InfoMessage "Using provided credentials for container admin user."
}
elseif ($PSBoundParameters.ContainsKey('Password')) {
    # Create credential from provided secure password
    $credential = New-Object pscredential 'admin', $Password
    Write-InfoMessage "Using default username with provided secure password."
}
else {
    # Create credential with default password
    $defaultSecurePassword = ConvertTo-SecureString -String "P@ssw0rd" -AsPlainText -Force
    $credential = New-Object pscredential 'admin', $defaultSecurePassword
    Write-InfoMessage "Using default credentials (admin/P@ssw0rd)."
}

# Use artifact URL from configuration or get latest sandbox artifact
$artifactUrl = ""
if (-not [string]::IsNullOrEmpty($config.ArtifactUrl)) {
    $artifactUrl = $config.ArtifactUrl
    Write-InfoMessage "Using artifact URL from configuration: $artifactUrl"
} else {
    Write-InfoMessage "Getting latest sandbox artifact..."
    $artifactUrl = Get-BcArtifactUrl -type 'Sandbox' -country $Country -select 'Latest'
    Write-InfoMessage "Using latest sandbox artifact: $artifactUrl"
}

try {
    # Create the container using configuration settings
    Write-InfoMessage "Creating container using artifact URL..."

    # Build parameter hashtable for New-BcContainer
    $containerParams = @{
        accept_eula = $Accept_Eula
        containerName = $ContainerName
        credential = $credential
        auth = $Auth
        artifactUrl = $artifactUrl
        includeTestToolkit = $IncludeTestToolkit
        includePerformanceToolkit = $IncludePerformanceToolkit
        assignPremiumPlan = $AssignPremiumPlan
    }

    # Add DNS if specified in configuration
    if ($config.DNS) {
        $containerParams['dns'] = $config.DNS
    }

    # Add UpdateHosts if specified in configuration
    if ($config.UpdateHosts) {
        $containerParams['updateHosts'] = $config.UpdateHosts
    }

    # Add memory limit if specified
    if (-not [string]::IsNullOrEmpty($MemoryLimit)) {
        $containerParams['memoryLimit'] = $MemoryLimit
    }

    # Create the container with all parameters
    Write-InfoMessage "Creating container with the following settings:"
    Write-InfoMessage "  Container Name: $ContainerName"
    Write-InfoMessage "  Auth Method: $Auth"
    Write-InfoMessage "  Include Test Toolkit: $IncludeTestToolkit"
    Write-InfoMessage "  Include Performance Toolkit: $IncludePerformanceToolkit"
    Write-InfoMessage "  Assign Premium Plan: $AssignPremiumPlan"

    New-BcContainer @containerParams

    # Setup test users
    Write-InfoMessage "Setting up test users..."
    Setup-BcContainerTestUsers -containerName $ContainerName -Password $credential.Password -credential $credential

    Write-SuccessMessage "Container '$ContainerName' setup completed successfully."
}
catch {
    Write-Host "ERROR: Failed to create or setup container: $_" -ForegroundColor Red
    # Exit with non-zero code to indicate failure
    exit 1
}

# Return container information
$containerInfo = docker container inspect $ContainerName | ConvertFrom-Json
$containerIP = $containerInfo.NetworkSettings.Networks.nat.IPAddress

# Return object with container details as a strongly-typed PSCustomObject for better tab-completion and type safety
$result = [PSCustomObject]@{
    ContainerName           = $ContainerName
    IPAddress               = $containerIP
    Auth                    = $Auth
    ArtifactUrl             = $artifactUrl
    Country                 = $Country
    IncludeTestToolkit      = $IncludeTestToolkit
    IncludePerformanceToolkit = $IncludePerformanceToolkit
    AssignPremiumPlan       = $AssignPremiumPlan
    MemoryLimit             = $MemoryLimit
    WebClientUrl            = "http://$containerIP/BC"
    SOAPServicesUrl         = "http://$containerIP/BC/WS"
    ODataServicesUrl        = "http://$containerIP/BC/ODataV4"
    ConfigPath              = $ConfigPath
    ConfigUsed              = (Test-Path -Path $ConfigPath)
}

# Output configuration information
Write-InfoMessage "Container created with the following configuration:"
Write-InfoMessage "  Configuration File: $ConfigPath (Used: $((Test-Path -Path $ConfigPath)))"
Write-InfoMessage "  Container Name: $ContainerName"
Write-InfoMessage "  Auth Method: $Auth"
Write-InfoMessage "  Country: $Country"
Write-InfoMessage "  Include Test Toolkit: $IncludeTestToolkit"
Write-InfoMessage "  Include Performance Toolkit: $IncludePerformanceToolkit"

# Return the result and exit with success code
return $result