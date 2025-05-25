<#
.SYNOPSIS
    Brief description of what the script does.
.DESCRIPTION
    Detailed description of what the script does, including:
    1. Purpose of the script
    2. Key functionality
    3. How it fits into the Business Central TDD workflow

    This script uses common utility functions from Common-Functions.ps1 and configuration
    from TDDConfig.psd1 for consistent functionality across the TDD workflow scripts.
.PARAMETER ConfigPath
    Path to the configuration file. Default is "scripts\TDDConfig.psd1" in the same directory as this script.
.PARAMETER Parameter1
    Description of Parameter1.
.PARAMETER Parameter2
    Description of Parameter2.
.EXAMPLE
    .\scripts\Script-Template.ps1
    # Runs the script with default parameters
.EXAMPLE
    .\scripts\Script-Template.ps1 -Parameter1 "Value1" -Parameter2 "Value2"
    # Runs the script with custom parameter values
.EXAMPLE
    .\scripts\Script-Template.ps1 -ConfigPath "C:\MyProject\CustomConfig.psd1"
    # Runs the script with a custom configuration file
.NOTES
    This script is part of the Business Central TDD workflow.

    Author: [Your Name]
    Date: [Current Date]
    Version: 1.0

    Change Log:
    1.0 - Initial version
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $false)]
    [string]$Parameter1,

    [Parameter(Mandatory = $false)]
    [string]$Parameter2
)

#region Script Initialization

# Fail fast on any terminating / non-terminating error
$ErrorActionPreference = 'Stop'
$VerbosePreference     = 'Continue'
$InformationPreference = 'Continue'
$WarningPreference     = 'Continue'

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

# Import Common-Functions.ps1
$commonFunctionsPath = Join-Path -Path $scriptDir -ChildPath "..\lib\Common-Functions.ps1"
if (-not (Test-Path -Path $commonFunctionsPath)) {
    Write-Error "Common-Functions.ps1 not found at path: $commonFunctionsPath. Make sure the script exists in the lib folder."
    exit 1
}
. $commonFunctionsPath

# Import Get-TDDConfiguration.ps1
$getTDDConfigPath = Join-Path -Path $scriptDir -ChildPath "..\lib\Get-TDDConfiguration.ps1"
if (-not (Test-Path -Path $getTDDConfigPath)) {
    Write-Error "Get-TDDConfiguration.ps1 not found at path: $getTDDConfigPath. Make sure the script exists in the lib folder."
    exit 1
}

# Load configuration
$configParams = @{}
if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
    $configParams['ConfigPath'] = $ConfigPath
}

$config = & $getTDDConfigPath @configParams

if (-not $config) {
    Write-ErrorMessage "Failed to load configuration. Please check the configuration file and try again."
    exit 1
}

# Apply script behavior settings from configuration
if ($config.ScriptSettings) {
    if ($config.ScriptSettings.ErrorActionPreference) {
        $ErrorActionPreference = $config.ScriptSettings.ErrorActionPreference
    }
    if ($config.ScriptSettings.VerboseOutput -eq $true) {
        $VerbosePreference = 'Continue'
    } else {
        $VerbosePreference = 'SilentlyContinue'
    }
    if ($config.ScriptSettings.WarningActionPreference) {
        $WarningPreference = $config.ScriptSettings.WarningActionPreference
    }
    if ($config.ScriptSettings.InformationPreference) {
        $InformationPreference = $config.ScriptSettings.InformationPreference
    }
    if ($config.ScriptSettings.ProgressPreference) {
        $ProgressPreference = $config.ScriptSettings.ProgressPreference
    }
}

#endregion

#region Functions

function Invoke-MainFunction {
    <#
    .SYNOPSIS
        Main function of the script.
    .DESCRIPTION
        Performs the main functionality of the script.
    .PARAMETER Config
        The configuration object.
    .PARAMETER Parameter1
        Description of Parameter1.
    .PARAMETER Parameter2
        Description of Parameter2.
    .OUTPUTS
        PSCustomObject. Returns an object with the results of the operation.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $false)]
        [string]$Parameter1,

        [Parameter(Mandatory = $false)]
        [string]$Parameter2
    )

    # Initialize result object
    $result = [PSCustomObject]@{
        Success = $false
        Message = ""
        Data = $null
        Timestamp = Get-Date
    }

    try {
        # Validate parameters
        if ([string]::IsNullOrWhiteSpace($Parameter1)) {
            $Parameter1 = "DefaultValue1"  # Set default value if not provided
        }

        if ([string]::IsNullOrWhiteSpace($Parameter2)) {
            $Parameter2 = "DefaultValue2"  # Set default value if not provided
        }

        # Display section header
        Write-SectionHeader "Main Function Execution" -ForegroundColor Cyan -DecorationType Underline

        # Display information about the operation
        Write-InfoMessage "Starting operation with the following parameters:"
        Write-InfoMessage "  Parameter1: $Parameter1"
        Write-InfoMessage "  Parameter2: $Parameter2"
        Write-InfoMessage "  Container Name: $($Config.ContainerName)"

        # Perform the main operation with error handling
        $operationSuccess = Invoke-ScriptWithErrorHandling -ScriptBlock {
            # TODO: Replace this with your actual script logic

            # Example: Check if Docker is running
            if (-not (Test-DockerRunning)) {
                throw "Docker is not running. Please start Docker and try again."
            }

            # Example: Check if container exists
            if (-not (Test-DockerContainerExists -ContainerName $Config.ContainerName)) {
                throw "Container '$($Config.ContainerName)' does not exist. Please create the container and try again."
            }

            # Example: Get container information
            $containerInfo = Get-DockerContainerInfo -ContainerName $Config.ContainerName
            if (-not $containerInfo) {
                throw "Failed to get container information for '$($Config.ContainerName)'."
            }

            # Example: Perform some operation
            # ... Your code here ...

            # Return data for the result object
            return @{
                ContainerInfo = $containerInfo
                Parameter1Value = $Parameter1
                Parameter2Value = $Parameter2
                # Add more data as needed
            }
        } -ErrorMessage "Failed to perform the operation"

        if ($operationSuccess -eq $true) {
            # Operation succeeded
            $result.Success = $true
            $result.Message = "Operation completed successfully."
            $result.Data = $operationSuccess  # This will contain the data returned from the script block

            Write-SuccessMessage $result.Message
        } else {
            # Operation failed
            $result.Success = $false
            $result.Message = "Operation failed. See previous error messages for details."

            Write-ErrorMessage $result.Message
        }
    }
    catch {
        # Handle any unexpected errors
        $result.Success = $false
        $result.Message = "An unexpected error occurred: $_"

        Write-ErrorMessage $result.Message
    }

    return $result
}

#endregion

#region Main Script Execution

# Display script header
Write-SectionHeader "Script Template" -ForegroundColor Cyan -DecorationType Box

# Execute the main function
$result = Invoke-MainFunction -Config $config -Parameter1 $Parameter1 -Parameter2 $Parameter2

# Return the result
return $result

#endregion

<#
HOW TO USE THIS TEMPLATE:

1. Save this file with a new name that describes your script's purpose (e.g., Publish-App.ps1).
2. Update the script header (Synopsis, Description, Parameters, Examples, Notes).
3. Replace the placeholder code in the Invoke-MainFunction with your actual script logic.
4. Add any additional functions you need.
5. Update the parameter validation and default values as needed.
6. Test your script with various parameter combinations.
7. Update the result object to include relevant data for your script.

BEST PRACTICES:

1. Use the common functions from Common-Functions.ps1 for consistent behavior.
2. Use the configuration from TDDConfig.psd1 for settings.
3. Handle errors gracefully using Invoke-ScriptWithErrorHandling.
4. Validate all parameters and provide sensible defaults.
5. Use Write-InfoMessage, Write-SuccessMessage, Write-ErrorMessage, and Write-WarningMessage for output.
6. Return a strongly-typed PSCustomObject with results.
7. Include detailed comments explaining your code.
8. Follow PowerShell best practices for naming conventions and code structure.
9. Use ShouldProcess for potentially destructive operations.
10. Include verbose output for debugging.

COMMON PATTERNS:

1. Loading configuration:
   $config = & $getTDDConfigPath @configParams

2. Validating parameters:
   if ([string]::IsNullOrWhiteSpace($Parameter1)) {
       $Parameter1 = $config.SomeDefaultValue
   }

3. Error handling:
   $success = Invoke-ScriptWithErrorHandling -ScriptBlock {
       # Your code here
   } -ErrorMessage "Failed to perform operation"

4. Returning results:
   return [PSCustomObject]@{
       Success = $true
       Message = "Operation completed successfully."
       Data = $someData
   }

5. Path resolution:
   $resolvedPath = Resolve-TDDPath -Path $somePath -BasePath $someBasePath -CreateIfNotExists

6. Docker operations:
   if (Test-DockerContainerRunning -ContainerName $config.ContainerName) {
       # Container is running, proceed with operations
   }

7. BcContainerHelper operations:
   if (Import-BcContainerHelperModule) {
       # Use BcContainerHelper cmdlets
   }
#>