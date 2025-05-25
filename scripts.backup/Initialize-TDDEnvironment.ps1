<#
.SYNOPSIS
    Initializes the environment for Business Central TDD workflow.
.DESCRIPTION
    This script sets up the environment for Business Central TDD workflow:
    1. Calls Verify-Environment.ps1 to ensure prerequisites are met
    2. If the container doesn't exist, creates it with appropriate settings
    3. If the container exists but isn't running, starts it
    4. Sets up any necessary environment variables for the TDD workflow

    The script uses settings from the TDDConfig.psd1 file, including container name,
    artifact URL, authentication method, and other container settings.
    If the configuration file cannot be loaded, default values are used.

    This script uses the centralized configuration management provided by Get-TDDConfiguration.ps1
    and common utility functions from Common-Functions.ps1.
.PARAMETER ContainerName
    The name of the Business Central container to initialize. Default is from configuration or 'bctest'.
.PARAMETER ImageName
    The Business Central Docker image to use. If not provided, latest sandbox artifact will be used.
.PARAMETER Auth
    Authentication method for the container. Valid options are 'Windows', 'UserPassword', or 'NavUserPassword'.
    Default is from configuration or 'NavUserPassword'.
.PARAMETER Credential
    Credentials for the container admin user. If not provided, default credentials (admin/P@ssw0rd) will be used.
    These credentials are forwarded to the SetupTestContainer.ps1 script.
.PARAMETER MemoryLimit
    Memory limit for the container. Default is from configuration or '8G'.
.PARAMETER Accept_Eula
    Whether to accept the EULA. Default is from configuration or $true.
.PARAMETER Accept_Outdated
    Whether to accept outdated images. Default is from configuration or $true.
.PARAMETER ConfigPath
    Path to the configuration file. Default is "scripts\TDDConfig.psd1" in the same directory as this script.
.PARAMETER SkipVerification
    Whether to skip the environment verification step. Default is $false.
.EXAMPLE
    .\Initialize-TDDEnvironment.ps1
    # Uses settings from the default configuration file
.EXAMPLE
    .\Initialize-TDDEnvironment.ps1 -ContainerName "mytest" -Auth "Windows"
    # Overrides configuration settings with provided parameters
.EXAMPLE
    .\Initialize-TDDEnvironment.ps1 -ConfigPath "C:\MyProject\CustomConfig.psd1"
    # Uses a custom configuration file
.NOTES
    This script is part of the Business Central TDD workflow.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ContainerName,

    [Parameter(Mandatory = $false)]
    [string]$ImageName = "",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Windows", "UserPassword", "NavUserPassword")]
    [string]$Auth,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Mandatory = $false)]
    [string]$MemoryLimit,

    [Parameter(Mandatory = $false)]
    [bool]$Accept_Eula,

    [Parameter(Mandatory = $false)]
    [bool]$Accept_Outdated,

    [Parameter(Mandatory = $false)]
    [bool]$SkipVerification = $false,

    [Parameter(Mandatory = $false)]
    [string]$ConfigPath
)

# Get the script directory
$scriptPath = $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($scriptPath)) {
    # Fallback if $MyInvocation.MyCommand.Path is empty
    $scriptPath = $PSCommandPath
}

if ([string]::IsNullOrWhiteSpace($scriptPath)) {
    # Hard-coded fallback if both are empty
    $scriptDir = "d:\repos\bctddflow\scripts"
    Write-Warning "Using hard-coded script directory: $scriptDir"
} else {
    $scriptDir = Split-Path -Parent $scriptPath
}

# Set default config path if not provided
if (-not $PSBoundParameters.ContainsKey('ConfigPath') -or [string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path -Path $scriptDir -ChildPath "TDDConfig.psd1"
    Write-Verbose "Using default configuration path: $ConfigPath"
}

# Import Common-Functions.ps1
$commonFunctionsPath = Join-Path -Path $scriptDir -ChildPath "Common-Functions.ps1"
if (-not (Test-Path -Path $commonFunctionsPath)) {
    Write-Error "Common-Functions.ps1 not found at path: $commonFunctionsPath. Make sure the script exists in the same folder as Initialize-TDDEnvironment.ps1."
    exit 1
}
. $commonFunctionsPath

# Import the Get-TDDConfiguration script
$getTDDConfigPath = Join-Path -Path $scriptDir -ChildPath "Get-TDDConfiguration.ps1"
if (-not (Test-Path -Path $getTDDConfigPath)) {
    Write-ErrorMessage "Get-TDDConfiguration.ps1 not found at path: $getTDDConfigPath" "Make sure the script exists in the same folder as Initialize-TDDEnvironment.ps1."
    exit 1
}
. $getTDDConfigPath

# Main function to initialize the TDD environment
function Initialize-BCTDDEnvironment {
    <#
    .SYNOPSIS
        Initializes the Business Central TDD environment.
    .DESCRIPTION
        Sets up the Business Central container for TDD workflow.
        Uses the centralized configuration management provided by Get-TDDConfiguration.ps1.
    .OUTPUTS
        System.Boolean. Returns $true if initialization is successful, $false otherwise.
    #>
    [CmdletBinding()]
    param()

    # Load configuration using the centralized Get-TDDConfiguration function
    $params = @{}
    if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
        $params['ConfigPath'] = $ConfigPath
    }

    $config = Get-TDDConfiguration @params

    # If configuration is null, exit with error
    if ($null -eq $config) {
        Write-ErrorMessage "Failed to load configuration. Please check the configuration file and try again."
        return $false
    }

    # Apply script settings from configuration if available
    if ($config.ScriptSettings) {
        if ($config.ScriptSettings.ErrorActionPreference) {
            $ErrorActionPreference = $config.ScriptSettings.ErrorActionPreference
        }
        if ($config.ScriptSettings.VerbosePreference) {
            $VerbosePreference = $config.ScriptSettings.VerbosePreference
        }
        if ($config.ScriptSettings.InformationPreference) {
            $InformationPreference = $config.ScriptSettings.InformationPreference
        }
        if ($config.ScriptSettings.WarningPreference) {
            $WarningPreference = $config.ScriptSettings.WarningPreference
        }
    }

    # Apply configuration values if parameters are not explicitly provided
    if (-not $PSBoundParameters.ContainsKey('ContainerName')) {
        $script:ContainerName = $config.ContainerName
    }

    if (-not $PSBoundParameters.ContainsKey('Auth')) {
        $script:Auth = $config.Auth
    }

    if (-not $PSBoundParameters.ContainsKey('MemoryLimit')) {
        $script:MemoryLimit = $config.MemoryLimit
    }

    if (-not $PSBoundParameters.ContainsKey('Accept_Eula')) {
        $script:Accept_Eula = $config.Accept_Eula
    }

    if (-not $PSBoundParameters.ContainsKey('Accept_Outdated')) {
        $script:Accept_Outdated = $config.Accept_Outdated
    }

    Write-SectionHeader "Business Central TDD Environment Initialization" -ForegroundColor Cyan
    Write-InfoMessage "Initializing environment for Business Central TDD workflow..."
    Write-InfoMessage "Using configuration from: $ConfigPath"
    $containerNameSource = if ($PSBoundParameters.ContainsKey('ContainerName')) { 'parameter' } else { 'configuration' }
    Write-InfoMessage "Container Name: $ContainerName (from $containerNameSource)"

    # Step 1: Verify environment prerequisites (unless skipped)
    if (-not $SkipVerification) {
        Write-InfoMessage "Verifying environment prerequisites..."
        $verifyScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Verify-Environment.ps1"

        if (-not (Test-PathIsFile -Path $verifyScriptPath)) {
            Write-ErrorMessage "Verify-Environment.ps1 script not found at path: $verifyScriptPath"
            return $false
        }

        $verifyResult = Invoke-ScriptWithErrorHandling -ScriptBlock {
            # Call the verification script but don't exit if it fails
            # We'll handle the container creation/startup if needed
            try {
                # Pass the configuration path to the verification script
                & $verifyScriptPath -ConfigPath $ConfigPath -ErrorAction Stop
                return $true  # If we get here, the script succeeded
            }
            catch {
                # The script exited with a non-zero exit code
                return $false
            }
        } -ErrorMessage "Error running Verify-Environment.ps1" -ContinueOnError

        # Log the verification result
        if ($verifyResult) {
            Write-InfoMessage "Environment verification passed."
        }
        else {
            Write-InfoMessage "Environment verification failed. Will attempt to resolve issues."
        }
    }
    else {
        Write-InfoMessage "Skipping environment verification as requested."
        $verifyResult = $true  # Assume verification passed when skipped
    }

    # Step 2: Check if BcContainerHelper module is available and try to import it
    # Check if we should suppress verbose output from BcContainerHelper
    $suppressVerbose = $false
    if ($config.ScriptSettings -and $config.ScriptSettings.SuppressBcContainerHelperVerbose) {
        $suppressVerbose = $config.ScriptSettings.SuppressBcContainerHelperVerbose
    }

    $bcContainerHelperAvailable = Import-BcContainerHelperModule -SuppressVerbose:$suppressVerbose

    if (-not $bcContainerHelperAvailable) {
        Write-ErrorMessage "BcContainerHelper module is not installed or cannot be imported." "Installing BcContainerHelper module..."
        try {
            Install-Module BcContainerHelper -Force
            $bcContainerHelperAvailable = Import-BcContainerHelperModule -Force -SuppressVerbose:$suppressVerbose

            if ($bcContainerHelperAvailable) {
                Write-SuccessMessage "BcContainerHelper module installed and imported successfully."
            } else {
                throw "Failed to import BcContainerHelper module after installation."
            }
        }
        catch {
            Write-ErrorMessage "Failed to install BcContainerHelper module: $_" "Please install the module manually by running: Install-Module BcContainerHelper -Force, then restart your PowerShell session."
            return $false
        }
    } else {
        Write-InfoMessage "BcContainerHelper module is available and imported."
    }

    # Step 3: Check if Docker is running
    $dockerRunning = Test-DockerRunning
    if (-not $dockerRunning) {
        Write-ErrorMessage "Docker is not running or not installed." "Make sure Docker Desktop is installed and running. If not installed, download it from https://www.docker.com/products/docker-desktop"
        return $false
    } else {
        Write-InfoMessage "Docker is running"
    }

    # Step 4: Check if container exists and create/start as needed
    $containerExists = Test-DockerContainerExists -ContainerName $ContainerName
    $containerRunning = $false

    if ($containerExists) {
        $containerRunning = Test-DockerContainerRunning -ContainerName $ContainerName
    }

    Write-InfoMessage "Container status: Exists=$containerExists, Running=$containerRunning"

    # Handle container creation or startup
    if (-not $containerExists) {
        Write-InfoMessage "Container '$ContainerName' does not exist. Creating new container..."

        # Prepare parameters for SetupTestContainer.ps1
        $setupParams = @{
            ContainerName = $ContainerName
            Auth = $Auth
            MemoryLimit = $MemoryLimit
            Accept_Eula = $Accept_Eula
            Accept_Outdated = $Accept_Outdated
            ConfigPath = $ConfigPath  # Pass the configuration path to SetupTestContainer.ps1
        }

        # Add ImageName if provided
        if (-not [string]::IsNullOrEmpty($ImageName)) {
            $setupParams.Add("ImageName", $ImageName)
        }

        # Forward credentials if provided
        if ($PSBoundParameters.ContainsKey('Credential')) {
            # Just pass the credential object directly
            $setupParams['Credential'] = $Credential
        }

        # Get the path to SetupTestContainer.ps1
        $setupScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "SetupTestContainer.ps1"

        if (-not (Test-PathIsFile -Path $setupScriptPath)) {
            Write-ErrorMessage "SetupTestContainer.ps1 script not found at path: $setupScriptPath"
            return $false
        }

        Write-InfoMessage "Setup parameters for container creation:"
        foreach ($key in $setupParams.Keys) {
            if ($key -ne "Credential" -and $key -ne "Password") {  # Don't log sensitive information
                Write-InfoMessage "  $key = $($setupParams[$key])"
            } else {
                Write-InfoMessage "  $key = [SECURED]"
            }
        }

        $setupSuccess = Invoke-ScriptWithErrorHandling -ScriptBlock {
            Write-InfoMessage "Calling SetupTestContainer.ps1 to create the container..."

            # Call the setup script and capture its output
            $script:containerInfo = & $setupScriptPath @setupParams

            # If we get here, the script succeeded
            Write-SuccessMessage "Container '$ContainerName' created successfully."
            $true
        } -ErrorMessage "Failed to create container '$ContainerName'"

        if ($setupSuccess) {
            $containerExists = $true
            $containerRunning = $true

            # Store container info for later use
            $script:containerDetails = $script:containerInfo
        } else {
            return $false
        }
    }
    elseif (-not $containerRunning) {
        Write-InfoMessage "Container '$ContainerName' exists but is not running. Starting container..."

        $startSuccess = Invoke-ScriptWithErrorHandling -ScriptBlock {
            # Try to use Start-BcContainer from BcContainerHelper module first
            if (Test-BcContainerHelperCommandAvailable -CommandName "Start-BcContainer") {
                Write-InfoMessage "Using BcContainerHelper to start the container..."
                Start-BcContainer -containerName $ContainerName
            }
            # Fall back to docker CLI if BcContainerHelper command is not available
            else {
                Write-InfoMessage "BcContainerHelper Start-BcContainer not available, using docker CLI instead..."
                docker start $ContainerName | Out-Null
            }
            $true
        } -ErrorMessage "Failed to start container '$ContainerName'"

        if ($startSuccess) {
            Write-SuccessMessage "Container '$ContainerName' started successfully."
            $containerRunning = $true
        } else {
            return $false
        }
    }
    else {
        Write-SuccessMessage "Container '$ContainerName' is already running."
    }

    # Step 5: Set up environment variables
    Write-InfoMessage "Setting up environment variables for TDD workflow..."

    # Set environment variables for the current session
    $env:BC_CONTAINER_NAME = $ContainerName
    $env:BC_CONTAINER_IMAGE = $ImageName

    # Set additional environment variables from configuration
    $env:BC_AUTH_METHOD = $Auth
    $env:BC_CONFIG_PATH = $ConfigPath

    # Set path variables from configuration if available
    if ($config.SourcePaths) {
        if ($config.SourcePaths.App) {
            $env:BC_APP_SOURCE_PATH = Resolve-TDDPath -Path $config.SourcePaths.App
        }
        if ($config.SourcePaths.Test) {
            $env:BC_TEST_SOURCE_PATH = Resolve-TDDPath -Path $config.SourcePaths.Test
        }
    }

    if ($config.OutputPaths) {
        if ($config.OutputPaths.Build) {
            $env:BC_BUILD_PATH = Resolve-TDDPath -Path $config.OutputPaths.Build -CreateIfNotExists
        }
        if ($config.OutputPaths.AppOutput) {
            $env:BC_APP_OUTPUT_PATH = Resolve-TDDPath -Path $config.OutputPaths.AppOutput -CreateIfNotExists
        }
        if ($config.OutputPaths.TestResults) {
            $env:BC_TEST_RESULTS_PATH = Resolve-TDDPath -Path $config.OutputPaths.TestResults -CreateIfNotExists
        }
    }

    Write-SuccessMessage "Environment variables set up successfully."
    Write-InfoMessage "Environment variables set:"
    Write-InfoMessage "  BC_CONTAINER_NAME = $env:BC_CONTAINER_NAME"
    Write-InfoMessage "  BC_CONTAINER_IMAGE = $env:BC_CONTAINER_IMAGE"
    Write-InfoMessage "  BC_AUTH_METHOD = $env:BC_AUTH_METHOD"
    Write-InfoMessage "  BC_CONFIG_PATH = $env:BC_CONFIG_PATH"

    if ($env:BC_APP_SOURCE_PATH) { Write-InfoMessage "  BC_APP_SOURCE_PATH = $env:BC_APP_SOURCE_PATH" }
    if ($env:BC_TEST_SOURCE_PATH) { Write-InfoMessage "  BC_TEST_SOURCE_PATH = $env:BC_TEST_SOURCE_PATH" }
    if ($env:BC_BUILD_PATH) { Write-InfoMessage "  BC_BUILD_PATH = $env:BC_BUILD_PATH" }
    if ($env:BC_APP_OUTPUT_PATH) { Write-InfoMessage "  BC_APP_OUTPUT_PATH = $env:BC_APP_OUTPUT_PATH" }
    if ($env:BC_TEST_RESULTS_PATH) { Write-InfoMessage "  BC_TEST_RESULTS_PATH = $env:BC_TEST_RESULTS_PATH" }

    # Step 6: Display container information
    if ($containerRunning) {
        Invoke-ScriptWithErrorHandling -ScriptBlock {
            # If container was just created, use the details returned by SetupTestContainer.ps1
            if ($script:containerDetails) {
                $containerIP = $script:containerDetails.IPAddress

                Write-SectionHeader "Container Information" -ForegroundColor Cyan
                Write-Host "  Name: $($script:containerDetails.ContainerName)" -ForegroundColor White
                Write-Host "  IP Address: $containerIP" -ForegroundColor White
                Write-Host "  Auth: $($script:containerDetails.Auth)" -ForegroundColor White
                Write-Host "  Status: Running" -ForegroundColor Green
                Write-Host "  Configuration: $($script:containerDetails.ConfigPath) (Used: $($script:containerDetails.ConfigUsed))" -ForegroundColor White

                Write-SectionHeader "Access Information" -ForegroundColor Cyan
                Write-Host "  Web Client: $($script:containerDetails.WebClientUrl)" -ForegroundColor White
                Write-Host "  SOAP Services: $($script:containerDetails.SOAPServicesUrl)" -ForegroundColor White
                Write-Host "  OData Services: $($script:containerDetails.ODataServicesUrl)" -ForegroundColor White
            }
            # Otherwise, get container information from Docker
            else {
                $containerInfo = Get-DockerContainerInfo -ContainerName $ContainerName
                if ($null -eq $containerInfo) {
                    throw "Failed to retrieve container information"
                }

                $containerIP = $containerInfo.IPAddress

                Write-SectionHeader "Container Information" -ForegroundColor Cyan
                Write-Host "  Name: $ContainerName" -ForegroundColor White
                Write-Host "  Image: $($containerInfo.Image)" -ForegroundColor White
                Write-Host "  IP Address: $containerIP" -ForegroundColor White
                Write-Host "  Status: $($containerInfo.State)" -ForegroundColor Green
                Write-Host "  Configuration: $ConfigPath (Used: $(Test-PathIsFile -Path $ConfigPath))" -ForegroundColor White
                Write-Host "  Auth: $Auth" -ForegroundColor White

                Write-SectionHeader "Access Information" -ForegroundColor Cyan
                Write-Host "  Web Client: http://$containerIP/BC" -ForegroundColor White
                Write-Host "  SOAP Services: http://$containerIP/BC/WS" -ForegroundColor White
                Write-Host "  OData Services: http://$containerIP/BC/ODataV4" -ForegroundColor White
            }

            Write-SectionHeader "Environment Ready" -ForegroundColor Green -DecorationType Box
            Write-SuccessMessage "Environment is ready for Business Central TDD workflow!"
            Write-InfoMessage "Configuration used: $ConfigPath"

            return $true
        } -ErrorMessage "Failed to retrieve container information"

        # Even if we fail to display container information, we still consider the initialization successful
    }

    return $true
}

# Execute the initialization with error handling
$success = Invoke-ScriptWithErrorHandling -ScriptBlock {
    $result = Initialize-BCTDDEnvironment

    # Set the exit code for the script
    if (-not $result) {
        # Exit with non-zero code to indicate failure when used in scripts
        exit 1
    } else {
        # Exit with zero code to indicate success
        exit 0
    }
} -ErrorMessage "An unexpected error occurred during environment initialization"

if (-not $success) {
    exit 1
}