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

# Dot-source the Common-Functions.ps1 script to import common utility functions
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Parent $scriptPath
$commonFunctionsPath = Join-Path -Path $scriptDir -ChildPath "Common-Functions.ps1"

# Check if the Common-Functions.ps1 script exists
if (-not (Test-Path -Path $commonFunctionsPath)) {
    Write-Host "ERROR: Common-Functions.ps1 script not found at $commonFunctionsPath" -ForegroundColor Red
    exit 1
}

# Import common functions
. $commonFunctionsPath

# Get the path to the Get-TDDConfiguration script
$getTDDConfigPath = Join-Path -Path $scriptDir -ChildPath "Get-TDDConfiguration.ps1"

# Check if the Get-TDDConfiguration script exists
if (-not (Test-PathIsFile -Path $getTDDConfigPath)) {
    Write-ErrorMessage "Get-TDDConfiguration.ps1 script not found at $getTDDConfigPath"
    exit 1
}

# Load configuration using Get-TDDConfiguration
$configLoaded = Invoke-ScriptWithErrorHandling -ScriptBlock {
    & $getTDDConfigPath -ConfigPath $ConfigPath
} -ErrorMessage "Failed to load configuration"

# Check if configuration was loaded successfully
if (-not $configLoaded) {
    Write-ErrorMessage "Failed to load configuration" "Please check the configuration file and try again."
    exit 1
}

# Get the configuration
$config = & $getTDDConfigPath -ConfigPath $ConfigPath

# Check if configuration was loaded successfully
if ($null -eq $config) {
    Write-ErrorMessage "Failed to load configuration" "Please check the configuration file and try again."
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

# Ensure BcContainerHelper is available
$bcContainerHelperAvailable = Import-BcContainerHelperModule
if (-not $bcContainerHelperAvailable) {
    # Error message is already displayed by Import-BcContainerHelperModule
    exit 1
}

Write-InfoMessage "Setting up Business Central test container '$ContainerName'..."

# Validate container name
if (-not (Test-ValidContainerName -ContainerName $ContainerName)) {
    Write-ErrorMessage "Invalid container name: $ContainerName" "Container names must match the regex: [a-zA-Z0-9][a-zA-Z0-9_.-]+"
    exit 1
}

# Validate authentication method
if (-not (Test-ValidAuthMethod -Auth $Auth)) {
    Write-ErrorMessage "Invalid authentication method: $Auth" "Valid authentication methods are: Windows, UserPassword, NavUserPassword"
    exit 1
}

# Create secure credential
if ($PSBoundParameters.ContainsKey('Credential')) {
    # Use the provided credential
    $credential = $Credential

    # Validate credential
    if (-not (Test-ValidCredential -Credential $credential)) {
        Write-ErrorMessage "Invalid credential provided" "Ensure the credential has a valid username and password"
        exit 1
    }

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

    # Get the latest sandbox artifact with error handling
    $artifactUrlResult = Invoke-ScriptWithErrorHandling -ScriptBlock {
        Get-BcArtifactUrl -type 'Sandbox' -country $Country -select 'Latest'
    } -ErrorMessage "Failed to get latest sandbox artifact"

    if (-not $artifactUrlResult) {
        exit 1
    }

    $artifactUrl = Get-BcArtifactUrl -type 'Sandbox' -country $Country -select 'Latest'
    Write-InfoMessage "Using latest sandbox artifact: $artifactUrl"
}

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
    enableTaskScheduler = $false  # Disable Task Scheduler to prevent test failures
}

# Add shared folders for test results
$testResultsDir = Resolve-TDDPath -Path $config.OutputPaths.TestResults -CreateIfNotExists
Write-InfoMessage "Setting up shared folder for test results: $testResultsDir"
# Use the correct format for BcContainerHelper's additionalParameters
$containerParams['additionalParameters'] = @("-v ""$($testResultsDir):C:\TestResults""")

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

# Create the container with error handling
$containerCreated = Invoke-ScriptWithErrorHandling -ScriptBlock {
    New-BcContainer @containerParams
} -ErrorMessage "Failed to create container"

if (-not $containerCreated) {
    exit 1
}

# Setup test users with error handling
$usersSetup = Invoke-ScriptWithErrorHandling -ScriptBlock {
    Setup-BcContainerTestUsers -containerName $ContainerName -Password $credential.Password -credential $credential
} -ErrorMessage "Failed to setup test users"

if (-not $usersSetup) {
    Write-WarningMessage "Container was created but test users setup failed. You may need to set up users manually."
}
else {
    Write-SuccessMessage "Container '$ContainerName' setup completed successfully."
}

# Get container information using the common function
$containerInfo = Get-DockerContainerInfo -ContainerName $ContainerName

# Check if container information was retrieved successfully
if ($null -eq $containerInfo) {
    Write-ErrorMessage "Failed to retrieve container information" "Container was created but information could not be retrieved."
    exit 1
}

# Return object with container details as a strongly-typed PSCustomObject for better tab-completion and type safety
$result = [PSCustomObject]@{
    ContainerName           = $ContainerName
    IPAddress               = $containerInfo.IPAddress
    Auth                    = $Auth
    ArtifactUrl             = $artifactUrl
    Country                 = $Country
    IncludeTestToolkit      = $IncludeTestToolkit
    IncludePerformanceToolkit = $IncludePerformanceToolkit
    AssignPremiumPlan       = $AssignPremiumPlan
    MemoryLimit             = $MemoryLimit
    WebClientUrl            = "http://$($containerInfo.IPAddress)/BC"
    SOAPServicesUrl         = "http://$($containerInfo.IPAddress)/BC/WS"
    ODataServicesUrl        = "http://$($containerInfo.IPAddress)/BC/ODataV4"
    ConfigPath              = $ConfigPath
    ConfigUsed              = (Test-PathIsFile -Path $ConfigPath)
}

# Output configuration information
Write-InfoMessage "Container created with the following configuration:"
Write-InfoMessage "  Configuration File: $ConfigPath (Used: $((Test-PathIsFile -Path $ConfigPath)))"
Write-InfoMessage "  Container Name: $ContainerName"
Write-InfoMessage "  Auth Method: $Auth"
Write-InfoMessage "  Country: $Country"
Write-InfoMessage "  Include Test Toolkit: $IncludeTestToolkit"
Write-InfoMessage "  Include Performance Toolkit: $IncludePerformanceToolkit"
Write-InfoMessage "  Web Client URL: $($result.WebClientUrl)"

# Return the result and exit with success code
return $result