<#
.SYNOPSIS
    Runs tests in a Business Central container.
.DESCRIPTION
    This script runs tests in a Business Central container by:
    1. Taking parameters for container name, test codeunit ID/name with defaults from configuration
    2. Verifying the container exists and is running using structured Docker output formats
    3. Using BcContainerHelper to run the specified tests in the container with proper error handling
    4. Applying test settings from the configuration (timeout, fail behavior)
    5. Supporting running all tests or specific test codeunits
    6. Capturing test results and formatting them for easy reading
    7. Returning a strongly-typed [pscustomobject] with test results
    8. Returning appropriate exit code based on test success/failure

    The script uses settings from the TDDConfig.psd1 file, including container name,
    test settings, and script behavior settings.
.PARAMETER ConfigPath
    Path to the configuration file. Default is "scripts\TDDConfig.psd1" in the same directory as this script.
.PARAMETER ContainerName
    Name of the container to run tests in. Default is from configuration.
.PARAMETER TestCodeunit
    Name or ID of test codeunit to run. Wildcards (? and *) are supported. Default is * (all tests).
.PARAMETER TestFunction
    Name of test function to run. Wildcards (? and *) are supported. Default is * (all functions).
.PARAMETER ExtensionId
    Specifying an extensionId causes the test tool to run all tests in the app with this app id.
    Default is empty (run all tests).
.PARAMETER TestCodeunitRange
    A BC-compatible filter string to use for loading test codeunits (similar to -extensionId).
    If you set this parameter to '*', all test codeunits will be loaded.
    This parameter is optional and works independently of other test parameters.
.PARAMETER Detailed
    Include this switch to output success/failure information for all tests.
.PARAMETER FailFast
    Stop on first test failure. Default is from configuration.
.PARAMETER Timeout
    Timeout for test execution in seconds. Default is from configuration.
.EXAMPLE
    .\scripts\Run-Tests.ps1
    # Runs all tests using default settings from configuration
.EXAMPLE
    .\scripts\Run-Tests.ps1 -TestCodeunit "HelloWorld Test"
    # Runs only the specified test codeunit
.EXAMPLE
    .\scripts\Run-Tests.ps1 -TestCodeunit "HelloWorld Test" -TestFunction "TestHelloWorld"
    # Runs only the specified test function in the specified test codeunit
.EXAMPLE
    .\scripts\Run-Tests.ps1 -ExtensionId "12345678-1234-1234-1234-123456789012"
    # Runs all tests in the specified extension
.EXAMPLE
    .\scripts\Run-Tests.ps1 -TestCodeunitRange "*"
    # Loads all test codeunits using the testCodeunitRange parameter
.EXAMPLE
    .\scripts\Run-Tests.ps1 -Detailed
    # Runs all tests with detailed console output
.NOTES
    This script is part of the Business Central TDD workflow.

    Author: AI Assistant
    Date: 2023-11-15
    Version: 1.0

    Change Log:
    1.0 - Initial version
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $false)]
    [string]$ContainerName,

    [Parameter(Mandatory = $false)]
    [string]$TestCodeunit = "*",

    [Parameter(Mandatory = $false)]
    [string]$TestFunction = "*",

    [Parameter(Mandatory = $false)]
    [string]$ExtensionId = "",

    [Parameter(Mandatory = $false)]
    [string]$TestCodeunitRange = "",

    [Parameter(Mandatory = $false)]
    [switch]$Detailed,

    [Parameter(Mandatory = $false)]
    [switch]$FailFast,

    [Parameter(Mandatory = $false)]
    [int]$Timeout = 0,

    [Parameter(Mandatory = $false)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]
    [PSCredential]$Credential,

    [Parameter(Mandatory = $false)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]
    [SecureString]$Password
)

# Dot-source the Common-Functions.ps1 script
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Path $scriptPath -Parent
$commonFunctionsPath = Join-Path -Path $scriptDir -ChildPath "..\lib\Common-Functions.ps1"

if (Test-Path -Path $commonFunctionsPath) {
    . $commonFunctionsPath
} else {
    Write-Error "Common-Functions.ps1 not found at: $commonFunctionsPath"
    exit 1
}



# Set error handling preferences
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'
$InformationPreference = 'Continue'

# Load configuration using the centralized Get-TDDConfiguration function
$getTDDConfigPath = Join-Path -Path $scriptDir -ChildPath "..\lib\Get-TDDConfiguration.ps1"
if (Test-Path -Path $getTDDConfigPath) {
    . $getTDDConfigPath
} else {
    Write-ErrorMessage "Get-TDDConfiguration.ps1 not found at: $getTDDConfigPath"
    exit 1
}

# Load configuration
$params = @{}
if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
    $params['ConfigPath'] = $ConfigPath
}
$config = Get-TDDConfiguration @params

# Helper function to get extension ID from app.json
function Get-ExtensionIdFromAppJson {
    <#
    .SYNOPSIS
        Reads and extracts the extension ID from the test application's app.json file.
    .DESCRIPTION
        This function reads the test application's app.json file and extracts the extension ID.
        It uses the centralized configuration to locate the test app.json file and includes
        robust error handling for various failure scenarios.
    .PARAMETER Config
        The configuration object containing SourcePaths.Test for locating the app.json file.
    .OUTPUTS
        System.String. Returns the extension ID from the app.json file.
    .EXAMPLE
        $extensionId = Get-ExtensionIdFromAppJson -Config $config
        # Reads the extension ID from the test app's app.json file
    .NOTES
        This function is part of the Business Central TDD workflow and uses the centralized
        configuration system to locate files.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    try {
        # Validate that the configuration contains the required SourcePaths.Test setting
        if (-not $Config.ContainsKey('SourcePaths') -or -not $Config.SourcePaths.ContainsKey('Test')) {
            throw "Configuration does not contain SourcePaths.Test setting. Please check your TDDConfig.psd1 file."
        }

        # Construct the path to app.json using the configuration
        $testSourcePath = $Config.SourcePaths.Test
        $appJsonRelativePath = Join-Path -Path $testSourcePath -ChildPath "app.json"

        # Use Resolve-TDDPath for proper path resolution
        $appJsonPath = Resolve-TDDPath -Path $appJsonRelativePath

        Write-InfoMessage "Looking for app.json at: $appJsonPath"

        # Check if app.json exists
        if (-not (Test-Path -Path $appJsonPath -PathType Leaf)) {
            throw "app.json file not found at path: $appJsonPath. Please ensure the test app contains a valid app.json file."
        }

        # Read and parse app.json
        Write-InfoMessage "Reading app.json file..."
        $appJsonContent = Get-Content -Path $appJsonPath -Raw -ErrorAction Stop

        if ([string]::IsNullOrWhiteSpace($appJsonContent)) {
            throw "app.json file is empty at path: $appJsonPath"
        }

        # Parse JSON content
        try {
            $appJsonObject = $appJsonContent | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            throw "Invalid JSON format in app.json file at path: $appJsonPath. Error: $($_.Exception.Message)"
        }

        # Check if the 'id' field exists
        if (-not $appJsonObject.PSObject.Properties.Name -contains 'id') {
            throw "app.json file at path: $appJsonPath is missing the required 'id' field."
        }

        # Validate that the ID is not null or empty
        $extensionId = $appJsonObject.id
        if ([string]::IsNullOrWhiteSpace($extensionId)) {
            throw "Extension ID in app.json file at path: $appJsonPath is null or empty."
        }

        Write-InfoMessage "Successfully read extension ID from app.json: $extensionId"
        return $extensionId.ToString()
    }
    catch {
        Write-ErrorMessage "Failed to read extension ID from app.json: $($_.Exception.Message)"
        throw
    }
}

# Main function to run tests in a Business Central container
function Invoke-RunTest {
    <#
    .SYNOPSIS
        Main function to run tests in a Business Central container.
    .DESCRIPTION
        Runs tests in a Business Central container using BcContainerHelper.
    .PARAMETER Config
        The configuration object.
    .PARAMETER ContainerName
        Name of the container to run tests in.
    .PARAMETER TestCodeunit
        Name or ID of test codeunit to run.
    .PARAMETER TestFunction
        Name of test function to run.
    .PARAMETER ExtensionId
        Extension ID to run tests for.
    .PARAMETER TestCodeunitRange
        A BC-compatible filter string to use for loading test codeunits.
    .PARAMETER Detailed
        Whether to output detailed test results.
    .PARAMETER FailFast
        Whether to stop on first test failure.
    .PARAMETER Timeout
        Timeout for test execution in seconds.
    .OUTPUTS
        PSCustomObject. Returns an object with the results of the operation.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $false)]
        [string]$ContainerName,

        [Parameter(Mandatory = $false)]
        [string]$TestCodeunit = "*",

        [Parameter(Mandatory = $false)]
        [string]$TestFunction = "*",

        [Parameter(Mandatory = $false)]
        [string]$ExtensionId = "",

        [Parameter(Mandatory = $false)]
        [string]$TestCodeunitRange = "",

        [Parameter(Mandatory = $false)]
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]
        [switch]$Detailed,

        [Parameter(Mandatory = $false)]
        [switch]$FailFast,

        [Parameter(Mandatory = $false)]
        [int]$Timeout = 0
    )

    # Initialize result object
    $result = [PSCustomObject]@{
        Success = $false
        Message = ""
        ContainerName = $null
        TestCodeunit = $null
        TestFunction = $null
        ExtensionId = $null
        TestsPassed = 0
        TestsFailed = 0
        TestsSkipped = 0
        TotalTests = 0
        Duration = $null
        AllTestsPassed = $false
        TestResults = $null
        Timestamp = Get-Date
    }

    try {
        # Validate parameters
        if ([string]::IsNullOrWhiteSpace($ContainerName)) {
            $ContainerName = $Config.ContainerName
        }
        $result.ContainerName = $ContainerName

        $result.TestCodeunit = $TestCodeunit
        $result.TestFunction = $TestFunction
        # ExtensionId will be set after resolution logic



        # Verify Docker is running
        if (-not (Test-DockerRunning)) {
            throw "Docker is not running. Please start Docker and try again."
        }

        # Verify container exists and is running
        if (-not (Test-DockerContainerExists -ContainerName $ContainerName)) {
            throw "Container '$ContainerName' does not exist. Please create the container using Initialize-TDDEnvironment.ps1 and try again."
        }

        if (-not (Test-DockerContainerRunning -ContainerName $ContainerName)) {
            throw "Container '$ContainerName' is not running. Please start the container and try again."
        }

        # Import BcContainerHelper module
        # Check if we should suppress verbose output from BcContainerHelper
        $suppressVerbose = $false
        if ($config.ScriptSettings -and $config.ScriptSettings.SuppressBcContainerHelperVerbose) {
            $suppressVerbose = $config.ScriptSettings.SuppressBcContainerHelperVerbose
        }

        if (-not (Import-BcContainerHelperModule -SuppressVerbose:$suppressVerbose)) {
            throw "BcContainerHelper module is not installed or cannot be imported. Please install the module and try again."
        }

        # Check if required BcContainerHelper commands are available
        $requiredCommands = @("Run-TestsInBcContainer")
        foreach ($command in $requiredCommands) {
            if (-not (Test-BcContainerHelperCommandAvailable -CommandName $command)) {
                throw "Required BcContainerHelper command '$command' is not available. Please update the BcContainerHelper module and try again."
            }
        }

        # Set test parameters
        $testParams = @{
            containerName = $ContainerName
            testCodeunit = $TestCodeunit
            testFunction = $TestFunction
            returnTrueIfAllPassed = $true
            detailed = $true  # Always use detailed output for better diagnostics
        }

        # Add credentials if specified or create default credentials
        if ($Credential) {
            $testParams['credential'] = $Credential
        } elseif ($Password) {
            $testParams['credential'] = New-Object System.Management.Automation.PSCredential("admin", $Password)
        } else {
            # Create default credentials for NavUserPassword authentication
            # Use a more secure approach by reading from configuration or environment
            $defaultPasswordString = if ($Config.TestSettings.DefaultPassword) {
                $Config.TestSettings.DefaultPassword
            } else {
                "P@ssw0rd"
            }
            # Required for BC container authentication
            # PSScriptAnalyzer suppression: This is required for BC container authentication
            # SuppressMessage: PSAvoidUsingConvertToSecureStringWithPlainText - Required for BC container authentication
            $defaultPassword = ConvertTo-SecureString $defaultPasswordString -AsPlainText -Force
            $testParams['credential'] = New-Object System.Management.Automation.PSCredential("admin", $defaultPassword)
            Write-InfoMessage "Using default credentials for NavUserPassword authentication."
        }

        # Resolve extension ID using priority logic:
        # 1. Use ExtensionId parameter if provided
        # 2. Read from test\app.json if parameter is empty
        # 3. Throw error if both fail
        $resolvedExtensionId = ""

        if (-not [string]::IsNullOrWhiteSpace($ExtensionId)) {
            # Priority 1: Use provided ExtensionId parameter
            $resolvedExtensionId = $ExtensionId
            Write-InfoMessage "Using extension ID from parameter: $resolvedExtensionId"
        }
        else {
            # Priority 2: Read from test\app.json
            try {
                Write-InfoMessage "ExtensionId parameter not provided, attempting to read from test\app.json..."
                $resolvedExtensionId = Get-ExtensionIdFromAppJson -Config $Config
                Write-InfoMessage "Successfully resolved extension ID from test\app.json: $resolvedExtensionId"
            }
            catch {
                # Priority 3: Throw error if both fail
                $errorMessage = "Failed to resolve extension ID. ExtensionId parameter was not provided and could not read from test\app.json. Error: $($_.Exception.Message)"
                Write-ErrorMessage $errorMessage "Provide the ExtensionId parameter or ensure test\app.json exists with a valid 'id' field."
                throw $errorMessage
            }
        }

        # Store the resolved extension ID in the result object
        $result.ExtensionId = $resolvedExtensionId

        # Always add resolved extension ID to test parameters (now required)
        if ([string]::IsNullOrWhiteSpace($resolvedExtensionId)) {
            throw "Extension ID is required but could not be resolved. Please provide ExtensionId parameter or ensure test\app.json exists with a valid 'id' field."
        }

        Write-InfoMessage "Using extension ID for test execution: $resolvedExtensionId"
        $testParams['extensionId'] = $resolvedExtensionId

        # Add testCodeunitRange parameter when provided and non-empty
        if (-not [string]::IsNullOrWhiteSpace($TestCodeunitRange)) {
            $testParams['testCodeunitRange'] = $TestCodeunitRange
            Write-InfoMessage "Using testCodeunitRange parameter: $TestCodeunitRange"
        }

        # Log all active filtering parameters for transparency
        $activeFilters = @()
        if ($testParams.ContainsKey('extensionId')) {
            $activeFilters += "extensionId: $($testParams['extensionId'])"
        }
        if ($testParams.ContainsKey('testCodeunit') -and $testParams['testCodeunit'] -ne "*") {
            $activeFilters += "testCodeunit: $($testParams['testCodeunit'])"
        }
        if ($testParams.ContainsKey('testFunction') -and $testParams['testFunction'] -ne "*") {
            $activeFilters += "testFunction: $($testParams['testFunction'])"
        }
        if ($testParams.ContainsKey('testCodeunitRange')) {
            $activeFilters += "testCodeunitRange: $($testParams['testCodeunitRange'])"
        }

        if ($activeFilters.Count -gt 0) {
            Write-InfoMessage "Active test filtering parameters: $($activeFilters -join ', ')"
        }



        # We already set detailed = $true in the parameters

        # Set test runner codeunit ID if specified in config
        if (-not [string]::IsNullOrWhiteSpace($Config.TestSettings.TestRunnerCodeunitId)) {
            $testParams['testRunnerCodeunitId'] = $Config.TestSettings.TestRunnerCodeunitId
        }

        # Set timeout if specified
        if ($Timeout -gt 0) {
            $testParams['interactionTimeout'] = [TimeSpan]::FromSeconds($Timeout)
        } elseif ($Config.TestSettings.DefaultTimeout -gt 0) {
            $testParams['interactionTimeout'] = [TimeSpan]::FromSeconds($Config.TestSettings.DefaultTimeout)
        }

        # Set fail fast if specified
        if ($FailFast -or $Config.TestSettings.FailFast) {
            # Note: There's no direct parameter for fail fast in Run-TestsInBcContainer
            # This would need to be handled by the test runner codeunit in BC
            Write-InfoMessage "FailFast is enabled. Tests will stop on first failure if supported by the test runner."
        }

        # Run tests with error handling
        Write-InfoMessage "Running tests in container '$ContainerName'..."

        $startTime = Get-Date

        # Run the tests and capture the output
        Write-InfoMessage "Running tests in container '$ContainerName'..."

        # Run the tests and capture all output including console streams
        $transcriptPath = Join-Path -Path $env:TEMP -ChildPath "BCTestOutput_$(Get-Random).txt"
        
        try {
            Start-Transcript -Path $transcriptPath -Force | Out-Null
            
            $testOutput = Invoke-ScriptWithErrorHandling -ScriptBlock {
                Run-TestsInBcContainer @testParams
            } -ErrorMessage "Failed to run tests in container"
            
            Stop-Transcript | Out-Null
            
            # Read the transcript to get the full output
            if (Test-Path $transcriptPath) {
                $fullOutput = Get-Content -Path $transcriptPath -Raw
            } else {
                $fullOutput = ""
            }
        }
        finally {
            # Clean up transcript
            if (Test-Path $transcriptPath) {
                Remove-Item -Path $transcriptPath -Force -ErrorAction SilentlyContinue
            }
        }

        $endTime = Get-Date
        $duration = $endTime - $startTime
        $result.Duration = $duration

        # Process test results from the output
        $result.Success = $testOutput

        # Parse test results from output if available
        Write-InfoMessage "Processing test results..."
        try {
            $tests = @()
            $totalTests = 0
            $passedTests = 0
            $failedTests = 0
            $skippedTests = 0

            # Parse the test output to extract test results
            # Use the full transcript output which contains the detailed test results
            if ($fullOutput -and $fullOutput.Length -gt 0) {
                Write-InfoMessage "Parsing test output for results..."

                $testOutputLines = $fullOutput -split "`r?`n"
                
                $testResults = @()

                # Pattern for codeunit line: "  Codeunit 50000 HelloWorld Test Success (0.271 seconds)"
                $codeunitPattern = '^\s*Codeunit\s+(\d+)\s+(.*?)\s+(Success|Failure|Skipped)\s+\((.*?)\s+seconds\)'

                # Pattern for test function line: "    Testfunction TestHelloWorldMessage Success (0.157 seconds)"
                $testFunctionPattern = '^\s*Testfunction\s+(.*?)\s+(Success|Failure|Skipped)\s+\((.*?)\s+seconds\)'

                # Pattern for error message: "      Error:"
                $errorPattern = '^\s*Error:'

                $currentCodeunit = $null
                $currentCodeunitId = $null
                $inErrorSection = $false
                $errorLines = @()

                foreach ($line in $testOutputLines) {
                    # Check for codeunit line
                    if ($line -match $codeunitPattern) {
                        $currentCodeunitId = $matches[1]
                        $currentCodeunit = $matches[2]
                    }
                    # Check for test function line
                    elseif ($line -match $testFunctionPattern) {
                        $functionName = $matches[1]
                        $functionResult = $matches[2]
                        
                        # Collect any error message that was being built
                        $errorMessage = ""
                        if ($errorLines.Count -gt 0) {
                            $errorMessage = ($errorLines -join " ").Trim()
                            $errorLines = @()
                        }
                        
                        $testResults += [PSCustomObject]@{
                            TestCodeunit = $currentCodeunit
                            TestCodeunitId = $currentCodeunitId
                            TestFunction = $functionName
                            Result = $functionResult
                            ErrorMessage = $errorMessage
                        }
                        
                        $inErrorSection = $false
                    }
                    # Check for error section
                    elseif ($line -match $errorPattern) {
                        $inErrorSection = $true
                        $errorLines = @()
                    }
                    # Collect error message lines
                    elseif ($inErrorSection -and $line.Trim() -ne "" -and $line.Trim() -notmatch "Call Stack:") {
                        $errorLines += $line.Trim()
                    }
                    # Stop collecting error when we hit Call Stack or empty line
                    elseif ($inErrorSection -and ($line.Trim() -eq "" -or $line.Trim() -match "Call Stack:")) {
                        $inErrorSection = $false
                    }
                }

                # Use the parsed results if we found any
                if ($testResults.Count -gt 0) {
                    $tests = $testResults
                    Write-InfoMessage "Parsed $($tests.Count) test function(s) from output."

                    $totalTests = $tests.Count
                    $passedTests = 0
                    $failedTests = 0
                    $skippedTests = 0
                    
                    # Count results manually to avoid Where-Object issues
                    foreach ($test in $tests) {
                        switch ($test.Result) {
                            "Success" { $passedTests++ }
                            "Failure" { $failedTests++ }
                            "Skipped" { $skippedTests++ }
                        }
                    }
                    

                } else {
                    # If no test details were parsed, try to extract basic counts from the output
                    Write-WarningMessage "Failed to parse detailed test results from output. Attempting basic parsing..."
                    
                    # Try to count test functions in the output as a fallback
                    $testFunctionLines = $testOutputLines | Where-Object { $_ -match '^\s*Testfunction\s+.*\s+(Success|Failure|Skipped)\s+\(' }
                    
                    if ($testFunctionLines.Count -gt 0) {
                        $totalTests = $testFunctionLines.Count
                        $passedTests = 0
                        $failedTests = 0
                        $skippedTests = 0
                        
                        # Count results manually to avoid Where-Object issues
                        foreach ($line in $testFunctionLines) {
                            if ($line -match '\s+Success\s+\(') { $passedTests++ }
                            elseif ($line -match '\s+Failure\s+\(') { $failedTests++ }
                            elseif ($line -match '\s+Skipped\s+\(') { $skippedTests++ }
                        }
                        
                        Write-InfoMessage "Parsed $totalTests test functions: $passedTests passed, $failedTests failed, $skippedTests skipped"
                        $tests = @() # Empty array since we couldn't parse details
                    } else {
                        # Complete fallback - no test information could be extracted
                        Write-WarningMessage "Could not extract any test information from output."
                        $totalTests = 0
                        $passedTests = 0
                        $failedTests = 0
                        $skippedTests = 0
                        $tests = @()
                    }
                }
            } else {
                # No transcript output available, fall back to basic boolean result
                Write-WarningMessage "No transcript output available for parsing."
                if ($testOutput -eq $true) {
                    Write-InfoMessage "Test execution returned success, but no detailed results available."
                    $totalTests = 1
                    $passedTests = 1
                    $failedTests = 0
                    $skippedTests = 0
                    $tests = @()
                } else {
                    $totalTests = 0
                    $passedTests = 0
                    $failedTests = 0
                    $skippedTests = 0
                    $tests = @()
                }
            }



            $result.TotalTests = $totalTests
            $result.TestsPassed = $passedTests
            $result.TestsFailed = $failedTests
            $result.TestsSkipped = $skippedTests
            $result.AllTestsPassed = ($failedTests -eq 0)
            $result.TestResults = $tests

            # Display test results summary
            Write-SectionHeader "Test Results Summary"
            Write-InfoMessage "Total tests: $totalTests"
            Write-InfoMessage "Passed: $passedTests"
            if ($failedTests -gt 0) {
                Write-ErrorMessage "Failed: $failedTests"
            } else {
                Write-SuccessMessage "Failed: $failedTests"
            }
            Write-InfoMessage "Skipped: $skippedTests"
            Write-InfoMessage "Duration: $($duration.ToString('hh\:mm\:ss'))"

            # Display failed tests if any
            if ($failedTests -gt 0) {
                Write-SectionHeader "Failed Tests"
                $failedTestResults = $tests | Where-Object { $_.Result -eq "Failure" }
                foreach ($test in $failedTestResults) {
                    Write-ErrorMessage "$($test.TestCodeunit): $($test.TestFunction)" "$($test.ErrorMessage)"
                }
            }

            # Set success based on test results
            if ($result.AllTestsPassed) {
                $result.Success = $true
                $result.Message = "All tests passed successfully."
                Write-SuccessMessage "All tests passed successfully."
            } else {
                $result.Success = $false
                $result.Message = "Some tests failed."
                Write-ErrorMessage "Some tests failed. Check the test results for details."
            }


        } catch {
            Write-WarningMessage "Failed to parse test results: $_"
            $result.Success = $testOutput
            $result.Message = "Tests completed, but failed to parse test details."
        }

        return $result
    } catch {
        $errorMessage = "Error running tests: $_"
        Write-ErrorMessage $errorMessage
        $result.Success = $false
        $result.Message = $errorMessage
        return $result
    }
}

# Execute the test run with error handling
$testResult = Invoke-RunTest -Config $config -ContainerName $ContainerName -TestCodeunit $TestCodeunit -TestFunction $TestFunction -ExtensionId $ExtensionId -TestCodeunitRange $TestCodeunitRange -Detailed:$Detailed -FailFast:$FailFast -Timeout $Timeout

# Return the test result object
return $testResult
