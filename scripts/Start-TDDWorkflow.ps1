<#
.SYNOPSIS
    Orchestrates the complete Business Central TDD workflow.
.DESCRIPTION
    This script provides a complete workflow for Business Central Test-Driven Development by:
    1. Taking parameters for app source directory, test app source directory, and container name
    2. Verifying the container exists and is running using structured Docker output formats
    3. Orchestrating the complete TDD workflow:
       - Preparing the app source for compilation
       - Preparing the test app source for compilation
       - Compiling the main application using alc.exe on the host machine
       - Compiling the test application using alc.exe on the host machine
       - Deploying the compiled app packages to the Business Central container
       - Running all tests or selected tests from the test app in the container
       - Viewing and analyzing test results
    4. Providing switches to control which steps to execute
    5. Handling proper sequencing (main app before test app)
    6. Returning a strongly-typed [pscustomobject] with workflow results

    This script uses common utility functions from Common-Functions.ps1 and configuration
    from TDDConfig.psd1 for consistent functionality across the TDD workflow scripts.
.PARAMETER ConfigPath
    Path to the configuration file. Default is "scripts\TDDConfig.psd1" in the same directory as this script.
.PARAMETER AppSourceDirectory
    Path to the main app source directory. If not specified, uses the path from configuration.
.PARAMETER TestAppSourceDirectory
    Path to the test app source directory. If not specified, uses the path from configuration.
.PARAMETER ContainerName
    Name of the container to deploy to and run tests in. If not specified, uses the container name from configuration.
.PARAMETER PrepareOnly
    Only prepare the app source for compilation (don't compile, deploy, or run tests).
.PARAMETER CompileOnly
    Only prepare and compile the apps (don't deploy or run tests).
.PARAMETER DeployOnly
    Only deploy the apps (assumes apps are already compiled).
.PARAMETER TestOnly
    Only run tests (assumes apps are already deployed).
.PARAMETER SkipPrepare
    Skip the preparation step (assumes source is already prepared).
.PARAMETER SkipCompile
    Skip the compilation step (assumes apps are already compiled).
.PARAMETER SkipDeploy
    Skip the deployment step (assumes apps are already deployed).
.PARAMETER SkipTests
    Skip running tests.
.PARAMETER SkipResults
    Skip displaying test results.
.PARAMETER TestCodeunit
    Name or ID of test codeunit to run. Wildcards (? and *) are supported. Default is * (all tests).
.PARAMETER TestFunction
    Name of test function to run. Wildcards (? and *) are supported. Default is * (all functions).
.PARAMETER ExtensionId
    Specifying an extensionId causes the test tool to run all tests in the app with this app id.
.PARAMETER TestCodeunitRange
    A BC-compatible filter string to use for loading test codeunits (similar to -extensionId).
    This is not to be confused with -testCodeunit. If you set this parameter to '*', all test codeunits will be loaded.
.PARAMETER Detailed
    Include this switch to output success/failure information for all tests.
.PARAMETER ShowPassed
    Include this switch to show passed tests in the output. Default is to show only failed tests.
.EXAMPLE
    .\scripts\Start-TDDWorkflow.ps1
    # Executes the complete workflow with defaults from configuration
.EXAMPLE
    .\scripts\Start-TDDWorkflow.ps1 -CompileOnly
    # Only prepares and compiles the apps (doesn't deploy or run tests)
.EXAMPLE
    .\scripts\Start-TDDWorkflow.ps1 -DeployOnly
    # Only deploys the apps (assumes apps are already compiled)
.EXAMPLE
    .\scripts\Start-TDDWorkflow.ps1 -TestOnly -TestCodeunit "HelloWorld Test"
    # Only runs the specified test (assumes apps are already deployed)
.EXAMPLE
    .\scripts\Start-TDDWorkflow.ps1 -SkipTests
    # Executes all steps except running tests
.NOTES
    This script is part of the Business Central TDD workflow.

    Author: AI Assistant
    Date: 2023-11-16
    Version: 1.0

    Change Log:
    1.0 - Initial version
#>

[CmdletBinding(DefaultParameterSetName = "Complete")]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $false)]
    [string]$AppSourceDirectory,

    [Parameter(Mandatory = $false)]
    [string]$TestAppSourceDirectory,

    [Parameter(Mandatory = $false)]
    [string]$ContainerName,

    [Parameter(Mandatory = $false, ParameterSetName = "PrepareOnly")]
    [switch]$PrepareOnly,

    [Parameter(Mandatory = $false, ParameterSetName = "CompileOnly")]
    [switch]$CompileOnly,

    [Parameter(Mandatory = $false, ParameterSetName = "DeployOnly")]
    [switch]$DeployOnly,

    [Parameter(Mandatory = $false, ParameterSetName = "TestOnly")]
    [switch]$TestOnly,

    [Parameter(Mandatory = $false, ParameterSetName = "Complete")]
    [switch]$SkipPrepare,

    [Parameter(Mandatory = $false, ParameterSetName = "Complete")]
    [switch]$SkipCompile,

    [Parameter(Mandatory = $false, ParameterSetName = "Complete")]
    [switch]$SkipDeploy,

    [Parameter(Mandatory = $false, ParameterSetName = "Complete")]
    [switch]$SkipTests,

    [Parameter(Mandatory = $false, ParameterSetName = "Complete")]
    [switch]$SkipResults,

    [Parameter(Mandatory = $false)]
    [string]$TestCodeunit = "*",

    [Parameter(Mandatory = $false)]
    [string]$TestFunction = "*",

    [Parameter(Mandatory = $false)]
    [string]$ExtensionId,

    [Parameter(Mandatory = $false)]
    [string]$TestCodeunitRange,

    [Parameter(Mandatory = $false)]
    [switch]$Detailed,

    [Parameter(Mandatory = $false)]
    [switch]$ShowPassed
)

#region Script Initialization

# Fail fast on any terminating / non-terminating error
$ErrorActionPreference = 'Stop'
$VerbosePreference     = 'Continue'
$InformationPreference = 'Continue'
$WarningPreference     = 'Continue'

# Import Common-Functions.ps1 first to access centralized project root function
$scriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptDir)) {
    Write-Error "Unable to determine script directory. PSScriptRoot is not available. This script must be run as a file, not in an interactive session."
    exit 1
}

$commonFunctionsPath = Join-Path -Path $scriptDir -ChildPath "lib\Common-Functions.ps1"
if (-not (Test-Path -Path $commonFunctionsPath)) {
    Write-Error "Common-Functions.ps1 not found at path: $commonFunctionsPath. Make sure the script exists in the lib folder."
    exit 1
}
. $commonFunctionsPath

# Initialize project root using centralized function
$projectInfo = Initialize-TDDProjectRoot -ScriptRoot $scriptDir
if (-not $projectInfo.ValidationPassed) {
    exit 1
}

# Extract values for backward compatibility
$scriptDir = $projectInfo.ScriptDir

# Import Get-TDDConfiguration.ps1
$getTDDConfigPath = Join-Path -Path $scriptDir -ChildPath "lib\Get-TDDConfiguration.ps1"
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

function Invoke-TDDWorkflow {
    <#
    .SYNOPSIS
        Main function that orchestrates the TDD workflow.
    .DESCRIPTION
        Performs the complete TDD workflow or specific parts based on parameters.
    .PARAMETER Config
        The configuration object.
    .PARAMETER AppSourceDirectory
        Path to the main app source directory.
    .PARAMETER TestAppSourceDirectory
        Path to the test app source directory.
    .PARAMETER ContainerName
        Name of the container to deploy to and run tests in.
    .PARAMETER PrepareOnly
        Only prepare the app source for compilation.
    .PARAMETER CompileOnly
        Only prepare and compile the apps.
    .PARAMETER DeployOnly
        Only deploy the apps.
    .PARAMETER TestOnly
        Only run tests.
    .PARAMETER SkipPrepare
        Skip the preparation step.
    .PARAMETER SkipCompile
        Skip the compilation step.
    .PARAMETER SkipDeploy
        Skip the deployment step.
    .PARAMETER SkipTests
        Skip running tests.
    .PARAMETER SkipResults
        Skip displaying test results.
    .PARAMETER TestCodeunit
        Name or ID of test codeunit to run.
    .PARAMETER TestFunction
        Name of test function to run.
    .PARAMETER ExtensionId
        Extension ID to run tests for.
    .PARAMETER TestCodeunitRange
        A BC-compatible filter string to use for loading test codeunits.
    .PARAMETER Detailed
        Output detailed test information.
    .PARAMETER ShowPassed
        Show passed tests in the output.
    .OUTPUTS
        PSCustomObject. Returns an object with the results of the workflow.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $false)]
        [string]$AppSourceDirectory,

        [Parameter(Mandatory = $false)]
        [string]$TestAppSourceDirectory,

        [Parameter(Mandatory = $false)]
        [string]$ContainerName,

        [Parameter(Mandatory = $false)]
        [switch]$PrepareOnly,

        [Parameter(Mandatory = $false)]
        [switch]$CompileOnly,

        [Parameter(Mandatory = $false)]
        [switch]$DeployOnly,

        [Parameter(Mandatory = $false)]
        [switch]$TestOnly,

        [Parameter(Mandatory = $false)]
        [switch]$SkipPrepare,

        [Parameter(Mandatory = $false)]
        [switch]$SkipCompile,

        [Parameter(Mandatory = $false)]
        [switch]$SkipDeploy,

        [Parameter(Mandatory = $false)]
        [switch]$SkipTests,

        [Parameter(Mandatory = $false)]
        [switch]$SkipResults,

        [Parameter(Mandatory = $false)]
        [string]$TestCodeunit = "*",

        [Parameter(Mandatory = $false)]
        [string]$TestFunction = "*",

        [Parameter(Mandatory = $false)]
        [string]$ExtensionId,

        [Parameter(Mandatory = $false)]
        [string]$TestCodeunitRange,

        [Parameter(Mandatory = $false)]
        [switch]$Detailed,

        [Parameter(Mandatory = $false)]
        [switch]$ShowPassed
    )

    # Initialize result object
    $result = [PSCustomObject]@{
        Success = $true
        Message = "TDD workflow completed successfully."
        Steps = @{
            Prepare = @{
                Main = $null
                Test = $null
            }
            Compile = @{
                Main = $null
                Test = $null
            }
            Deploy = @{
                Main = $null
                Test = $null
            }
            Tests = $null
            Results = $null
        }
        Timestamp = Get-Date
    }

    try {
        # Validate parameters and set defaults
        if ([string]::IsNullOrWhiteSpace($ContainerName)) {
            $ContainerName = $Config.ContainerName
        }

        if ([string]::IsNullOrWhiteSpace($AppSourceDirectory)) {
            $AppSourceDirectory = $Config.SourcePaths.App
        }

        if ([string]::IsNullOrWhiteSpace($TestAppSourceDirectory)) {
            $TestAppSourceDirectory = $Config.SourcePaths.Test
        }

        # Determine which steps to execute based on parameters
        $runPrepare = -not $SkipPrepare -and -not $DeployOnly -and -not $TestOnly
        $runCompile = -not $SkipCompile -and -not $DeployOnly -and -not $TestOnly
        $runDeploy = -not $SkipDeploy -and -not $PrepareOnly -and -not $CompileOnly
        $runTests = -not $SkipTests -and -not $PrepareOnly -and -not $CompileOnly -and -not $DeployOnly
        $showResults = -not $SkipResults -and -not $PrepareOnly -and -not $CompileOnly -and -not $DeployOnly

        # Override based on specific mode switches
        if ($PrepareOnly) {
            $runPrepare = $true
            $runCompile = $false
            $runDeploy = $false
            $runTests = $false
            $showResults = $false
        }

        if ($CompileOnly) {
            $runPrepare = $true
            $runCompile = $true
            $runDeploy = $false
            $runTests = $false
            $showResults = $false
        }

        if ($DeployOnly) {
            $runPrepare = $false
            $runCompile = $false
            $runDeploy = $true
            $runTests = $false
            $showResults = $false
        }

        if ($TestOnly) {
            $runPrepare = $false
            $runCompile = $false
            $runDeploy = $false
            $runTests = $true
            $showResults = $true
        }

        # Display workflow header
        Write-SectionHeader "Business Central TDD Workflow" -ForegroundColor Cyan -DecorationType Box

        # Display workflow configuration
        Write-InfoMessage "Starting TDD workflow with the following configuration:"
        Write-InfoMessage "  Container Name: $ContainerName"
        Write-InfoMessage "  Main App Source: $AppSourceDirectory"
        Write-InfoMessage "  Test App Source: $TestAppSourceDirectory"
        Write-InfoMessage "  Steps to execute:"
        Write-InfoMessage "    - Prepare: $runPrepare"
        Write-InfoMessage "    - Compile: $runCompile"
        Write-InfoMessage "    - Deploy: $runDeploy"
        Write-InfoMessage "    - Run Tests: $runTests"
        Write-InfoMessage "    - Show Results: $showResults"

        # Verify environment
        Write-SectionHeader "Verifying Environment" -ForegroundColor Cyan -DecorationType Underline

        $verifyEnvPath = Join-Path -Path $scriptDir -ChildPath "internal\Verify-Environment.ps1"
        if (-not (Test-Path -Path $verifyEnvPath)) {
            throw "Verify-Environment.ps1 not found at path: $verifyEnvPath"
        }

        $verifyParams = @{}
        if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
            $verifyParams['ConfigPath'] = $ConfigPath
        }

        & $verifyEnvPath @verifyParams

        # The Verify-Environment.ps1 script returns a string message on success, not an object
        # So we need to check if it completed without throwing an error
        if ($LASTEXITCODE -ne 0) {
            throw "Environment verification failed. Please check the error messages and try again."
        }

        Write-SuccessMessage "Environment verification completed successfully."

        # Prepare app source
        if ($runPrepare) {
            Write-SectionHeader "Preparing App Source" -ForegroundColor Cyan -DecorationType Underline

            $prepareAppPath = Join-Path -Path $scriptDir -ChildPath "workflow\Prepare-AppSource.ps1"
            if (-not (Test-Path -Path $prepareAppPath)) {
                throw "Prepare-AppSource.ps1 not found at path: $prepareAppPath"
            }

            # Prepare main app
            Write-InfoMessage "Preparing main app source..."
            $prepareMainParams = @{
                SourceDirectory = $AppSourceDirectory
                AppType = "Main"
            }

            if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
                $prepareMainParams['ConfigPath'] = $ConfigPath
            }

            $prepareMainResult = & $prepareAppPath @prepareMainParams

            if (-not $prepareMainResult -or -not $prepareMainResult.Success) {
                throw "Failed to prepare main app source. Please check the error messages and try again."
            }

            $result.Steps.Prepare.Main = $prepareMainResult
            Write-SuccessMessage "Main app source prepared successfully."

            # Prepare test app
            Write-InfoMessage "Preparing test app source..."
            $prepareTestParams = @{
                SourceDirectory = $TestAppSourceDirectory
                AppType = "Test"
            }

            if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
                $prepareTestParams['ConfigPath'] = $ConfigPath
            }

            $prepareTestResult = & $prepareAppPath @prepareTestParams

            if (-not $prepareTestResult -or -not $prepareTestResult.Success) {
                throw "Failed to prepare test app source. Please check the error messages and try again."
            }

            $result.Steps.Prepare.Test = $prepareTestResult
            Write-SuccessMessage "Test app source prepared successfully."
        }

        # Compile apps
        if ($runCompile) {
            Write-SectionHeader "Compiling Apps" -ForegroundColor Cyan -DecorationType Underline

            $compileAppPath = Join-Path -Path $scriptDir -ChildPath "workflow\Compile-App.ps1"
            if (-not (Test-Path -Path $compileAppPath)) {
                throw "Compile-App.ps1 not found at path: $compileAppPath"
            }

            # Compile main app
            Write-InfoMessage "Compiling main app..."
            $compileMainParams = @{
                AppType = "Main"
            }

            if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
                $compileMainParams['ConfigPath'] = $ConfigPath
            }

            $compileMainResult = & $compileAppPath @compileMainParams

            if (-not $compileMainResult -or -not $compileMainResult.Success) {
                throw "Failed to compile main app. Please check the error messages and try again."
            }

            $result.Steps.Compile.Main = $compileMainResult
            Write-SuccessMessage "Main app compiled successfully."

            # Compile test app
            Write-InfoMessage "Compiling test app..."
            $compileTestParams = @{
                AppType = "Test"
            }

            if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
                $compileTestParams['ConfigPath'] = $ConfigPath
            }

            $compileTestResult = & $compileAppPath @compileTestParams

            if (-not $compileTestResult -or -not $compileTestResult.Success) {
                throw "Failed to compile test app. Please check the error messages and try again."
            }

            $result.Steps.Compile.Test = $compileTestResult
            Write-SuccessMessage "Test app compiled successfully."
        }

        # Deploy apps
        if ($runDeploy) {
            Write-SectionHeader "Deploying Apps" -ForegroundColor Cyan -DecorationType Underline

            $deployAppPath = Join-Path -Path $scriptDir -ChildPath "workflow\Deploy-App.ps1"
            if (-not (Test-Path -Path $deployAppPath)) {
                throw "Deploy-App.ps1 not found at path: $deployAppPath"
            }

            # Deploy main app
            Write-InfoMessage "Deploying main app..."
            $deployMainParams = @{
                AppType = "Main"
                ContainerName = $ContainerName
            }

            if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
                $deployMainParams['ConfigPath'] = $ConfigPath
            }

            $deployMainResult = & $deployAppPath @deployMainParams

            if (-not $deployMainResult -or -not $deployMainResult.Success) {
                throw "Failed to deploy main app. Please check the error messages and try again."
            }

            $result.Steps.Deploy.Main = $deployMainResult
            Write-SuccessMessage "Main app deployed successfully."

            # Deploy test app
            Write-InfoMessage "Deploying test app..."
            $deployTestParams = @{
                AppType = "Test"
                ContainerName = $ContainerName
            }

            if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
                $deployTestParams['ConfigPath'] = $ConfigPath
            }

            $deployTestResult = & $deployAppPath @deployTestParams

            if (-not $deployTestResult -or -not $deployTestResult.Success) {
                throw "Failed to deploy test app. Please check the error messages and try again."
            }

            $result.Steps.Deploy.Test = $deployTestResult
            Write-SuccessMessage "Test app deployed successfully."
        }

        # Run tests
        if ($runTests) {
            Write-SectionHeader "Running Tests" -ForegroundColor Cyan -DecorationType Underline

            $runTestsPath = Join-Path -Path $scriptDir -ChildPath "workflow\Run-Tests.ps1"
            if (-not (Test-Path -Path $runTestsPath)) {
                throw "Run-Tests.ps1 not found at path: $runTestsPath"
            }

            Write-InfoMessage "Running tests..."
            $runTestsParams = @{
                ContainerName = $ContainerName
                TestCodeunit = $TestCodeunit
                TestFunction = $TestFunction
            }

            if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
                $runTestsParams['ConfigPath'] = $ConfigPath
            }

            if (-not [string]::IsNullOrWhiteSpace($ExtensionId)) {
                $runTestsParams['ExtensionId'] = $ExtensionId
            }

            if (-not [string]::IsNullOrWhiteSpace($TestCodeunitRange)) {
                $runTestsParams['TestCodeunitRange'] = $TestCodeunitRange
            }

            if ($Detailed) {
                $runTestsParams['Detailed'] = $true
            }

            $runTestsResult = & $runTestsPath @runTestsParams

            if (-not $runTestsResult) {
                throw "Failed to run tests. Please check the error messages and try again."
            }

            $result.Steps.Tests = $runTestsResult

            if ($runTestsResult.Success) {
                Write-SuccessMessage "Tests completed successfully."
            } else {
                Write-ErrorMessage "Tests completed with failures."
                $result.Success = $false
                $result.Message = "TDD workflow completed with test failures."
            }
        }

        # Show test results
        if ($showResults) {
            Write-SectionHeader "Test Results" -ForegroundColor Cyan -DecorationType Underline

            # Test results are now displayed directly by Run-Tests.ps1
            # No separate View-TestResults.ps1 script is needed since file output was removed
            if ($result.Steps.Tests) {
                Write-InfoMessage "Test results were displayed during test execution."
                Write-InfoMessage "Summary:"
                Write-InfoMessage "  Total Tests: $($result.Steps.Tests.TotalTests)"
                Write-InfoMessage "  Passed: $($result.Steps.Tests.TestsPassed)"
                Write-InfoMessage "  Failed: $($result.Steps.Tests.TestsFailed)"
                Write-InfoMessage "  Skipped: $($result.Steps.Tests.TestsSkipped)"
                
                if ($result.Steps.Tests.TestsFailed -gt 0) {
                    Write-WarningMessage "Some tests failed. See detailed output above."
                } else {
                    Write-SuccessMessage "All tests passed successfully."
                }
                
                $result.Steps.Results = $result.Steps.Tests
            } else {
                Write-InfoMessage "No test results available to display."
            }
        }

        # Display workflow summary
        Write-SectionHeader "Workflow Summary" -ForegroundColor Cyan -DecorationType Underline

        Write-InfoMessage "TDD workflow steps executed:"
        if ($runPrepare) {
            Write-InfoMessage "  - Prepare: Completed"
        }
        if ($runCompile) {
            Write-InfoMessage "  - Compile: Completed"
        }
        if ($runDeploy) {
            Write-InfoMessage "  - Deploy: Completed"
        }
        if ($runTests) {
            $testStatus = if ($result.Steps.Tests.Success) { "Passed" } else { "Failed" }
            Write-InfoMessage "  - Tests: $testStatus"
        }
        if ($showResults) {
            Write-InfoMessage "  - Results: Displayed"
        }

        if ($result.Success) {
            Write-SuccessMessage $result.Message
        } else {
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

# Execute the TDD workflow
$result = Invoke-TDDWorkflow -Config $config `
    -AppSourceDirectory $AppSourceDirectory `
    -TestAppSourceDirectory $TestAppSourceDirectory `
    -ContainerName $ContainerName `
    -PrepareOnly:$PrepareOnly `
    -CompileOnly:$CompileOnly `
    -DeployOnly:$DeployOnly `
    -TestOnly:$TestOnly `
    -SkipPrepare:$SkipPrepare `
    -SkipCompile:$SkipCompile `
    -SkipDeploy:$SkipDeploy `
    -SkipTests:$SkipTests `
    -SkipResults:$SkipResults `
    -TestCodeunit $TestCodeunit `
    -TestFunction $TestFunction `
    -ExtensionId $ExtensionId `
    -TestCodeunitRange $TestCodeunitRange `
    -Detailed:$Detailed `
    -ShowPassed:$ShowPassed

# Return the result
return $result

#endregion