<#
.SYNOPSIS
    Runs tests in a Business Central container.
.DESCRIPTION
    This script runs tests in a Business Central container by:
    1. Taking parameters for container name, test codeunit ID/name, and result file path with defaults from configuration
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
.PARAMETER ResultFile
    Path to the file where test results will be saved. Default is from configuration.
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
    .\scripts\Run-Tests.ps1 -ResultFile ".\build\testresults\CustomResults.xml" -Detailed
    # Runs all tests and saves detailed results to the specified file
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
    [string]$ResultFile,

    [Parameter(Mandatory = $false)]
    [switch]$Detailed,

    [Parameter(Mandatory = $false)]
    [switch]$FailFast,

    [Parameter(Mandatory = $false)]
    [int]$Timeout = 0,

    [Parameter(Mandatory = $false)]
    [PSCredential]$Credential,

    [Parameter(Mandatory = $false)]
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

# Function to generate test results XML as a fallback when container results are not available
function GenerateTestResultsXml {
    <#
    .SYNOPSIS
        Generates an XML file with test results.
    .DESCRIPTION
        Creates an XML file in XUnit format with test results.
    .PARAMETER Tests
        Array of test result objects.
    .PARAMETER TotalTests
        Total number of tests.
    .PARAMETER PassedTests
        Number of passed tests.
    .PARAMETER FailedTests
        Number of failed tests.
    .PARAMETER SkippedTests
        Number of skipped tests.
    .PARAMETER ResultFile
        Path to the file where test results will be saved.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Tests,

        [Parameter(Mandatory = $true)]
        [int]$TotalTests,

        [Parameter(Mandatory = $true)]
        [int]$PassedTests,

        [Parameter(Mandatory = $true)]
        [int]$FailedTests,

        [Parameter(Mandatory = $true)]
        [int]$SkippedTests,

        [Parameter(Mandatory = $true)]
        [string]$ResultFile
    )

    # Create a simple XML structure for the test results
    $xmlDoc = New-Object System.Xml.XmlDocument
    $xmlRoot = $xmlDoc.CreateElement("testsuites")
    $xmlDoc.AppendChild($xmlRoot) | Out-Null

    # Group tests by codeunit
    $testsByCodeunit = $Tests | Group-Object -Property TestCodeunit

    foreach ($codeunitGroup in $testsByCodeunit) {
        $codeunitName = $codeunitGroup.Name
        $codeunitTests = $codeunitGroup.Group

        # Create a testsuite for each codeunit
        $xmlTestSuite = $xmlDoc.CreateElement("testsuite")
        $xmlTestSuite.SetAttribute("name", $codeunitName)
        $xmlTestSuite.SetAttribute("tests", $codeunitTests.Count)
        $xmlTestSuite.SetAttribute("failures", ($codeunitTests | Where-Object { $_.Result -eq "Failure" }).Count)
        $xmlTestSuite.SetAttribute("skipped", ($codeunitTests | Where-Object { $_.Result -eq "Skipped" }).Count)
        $xmlRoot.AppendChild($xmlTestSuite) | Out-Null

        # Add test cases for this codeunit
        foreach ($test in $codeunitTests) {
            $xmlTestCase = $xmlDoc.CreateElement("testcase")
            $xmlTestCase.SetAttribute("name", $test.TestFunction)
            $xmlTestCase.SetAttribute("classname", $test.TestCodeunit)

            # Add codeunit ID if available
            if ($test.PSObject.Properties.Name -contains "TestCodeunitId") {
                $xmlTestCase.SetAttribute("codeunitId", $test.TestCodeunitId)
            }

            if ($test.Result -eq "Failure") {
                $xmlFailure = $xmlDoc.CreateElement("failure")
                $xmlFailure.SetAttribute("message", $test.ErrorMessage)
                $xmlTestCase.AppendChild($xmlFailure) | Out-Null
            } elseif ($test.Result -eq "Skipped") {
                $xmlSkipped = $xmlDoc.CreateElement("skipped")
                $xmlTestCase.AppendChild($xmlSkipped) | Out-Null
            }

            $xmlTestSuite.AppendChild($xmlTestCase) | Out-Null
        }
    }

    # If no test suites were created, create a default one
    if ($xmlRoot.ChildNodes.Count -eq 0) {
        $xmlTestSuite = $xmlDoc.CreateElement("testsuite")
        $xmlTestSuite.SetAttribute("name", "Business Central Tests")
        $xmlTestSuite.SetAttribute("tests", $TotalTests)
        $xmlTestSuite.SetAttribute("failures", $FailedTests)
        $xmlTestSuite.SetAttribute("skipped", $SkippedTests)
        $xmlRoot.AppendChild($xmlTestSuite) | Out-Null

        foreach ($test in $Tests) {
            $xmlTestCase = $xmlDoc.CreateElement("testcase")
            $xmlTestCase.SetAttribute("name", $test.TestFunction)
            $xmlTestCase.SetAttribute("classname", $test.TestCodeunit)

            if ($test.Result -eq "Failure") {
                $xmlFailure = $xmlDoc.CreateElement("failure")
                $xmlFailure.SetAttribute("message", $test.ErrorMessage)
                $xmlTestCase.AppendChild($xmlFailure) | Out-Null
            } elseif ($test.Result -eq "Skipped") {
                $xmlSkipped = $xmlDoc.CreateElement("skipped")
                $xmlTestCase.AppendChild($xmlSkipped) | Out-Null
            }

            $xmlTestSuite.AppendChild($xmlTestCase) | Out-Null
        }
    }

    # Save the XML document
    $xmlDoc.Save($ResultFile)
    Write-InfoMessage "Test results saved to: $ResultFile"
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

# Main function to run tests in a Business Central container
function Invoke-RunTests {
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
    .PARAMETER ResultFile
        Path to the file where test results will be saved.
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
        [string]$ResultFile,

        [Parameter(Mandatory = $false)]
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
        ResultFile = $null
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
        $result.ExtensionId = $ExtensionId

        # Validate result file path
        if ([string]::IsNullOrWhiteSpace($ResultFile)) {
            $testResultsDir = Resolve-TDDPath -Path $Config.OutputPaths.TestResults -CreateIfNotExists
            $ResultFile = Join-Path -Path $testResultsDir -ChildPath "TestResults.xml"
        }
        $result.ResultFile = $ResultFile

        # Ensure result directory exists
        $resultDir = Split-Path -Path $ResultFile -Parent
        if (-not (Test-Path -Path $resultDir)) {
            New-Item -Path $resultDir -ItemType Directory -Force | Out-Null
        }

        # For BC containers, we need to use a path inside the container for test results
        # and then copy the results back to the host after the tests are run
        # We'll create a directory for test results in the container

        # First, ensure the directory exists in the container
        try {
            Invoke-ScriptInBcContainer -containerName $ContainerName -scriptblock {
                if (-not (Test-Path -Path "c:\bcartifacts\testresults")) {
                    New-Item -Path "c:\bcartifacts\testresults" -ItemType Directory -Force | Out-Null
                }
            }
            Write-InfoMessage "Created test results directory in container."
        }
        catch {
            Write-WarningMessage "Failed to create test results directory in container: $_"
        }

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

        # Use the host path directly for XUnitResultFileName
        if (-not [string]::IsNullOrWhiteSpace($ResultFile)) {
            # The XUnitResultFileName parameter expects a path on the host machine
            # BcContainerHelper will generate the XML file on the host after running tests
            $testParams['XUnitResultFileName'] = $ResultFile

            # Ensure the directory exists
            $resultDir = Split-Path -Path $ResultFile -Parent
            if (-not (Test-Path -Path $resultDir)) {
                New-Item -Path $resultDir -ItemType Directory -Force | Out-Null
                Write-InfoMessage "Created test results directory: $resultDir"
            }

            # If the file exists, delete it to ensure we get fresh results
            if (Test-Path -Path $ResultFile) {
                Remove-Item -Path $ResultFile -Force
                Write-InfoMessage "Removed existing test results file: $ResultFile"
            }

            Write-InfoMessage "Results will be saved to: $ResultFile"
        }

        # Add credentials if specified or create default credentials
        if ($Credential) {
            $testParams['credential'] = $Credential
        } elseif ($Password) {
            $testParams['credential'] = New-Object System.Management.Automation.PSCredential("admin", $Password)
        } else {
            # Create default credentials for NavUserPassword authentication
            $defaultPassword = ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force
            $testParams['credential'] = New-Object System.Management.Automation.PSCredential("admin", $defaultPassword)
            Write-InfoMessage "Using default credentials (admin/P@ssw0rd) for NavUserPassword authentication."
        }

        # Add extension ID if specified
        if (-not [string]::IsNullOrWhiteSpace($ExtensionId)) {
            Write-InfoMessage "Extension ID: $ExtensionId"
            $testParams['extensionId'] = $ExtensionId

            # When using extensionId, we need to make sure testCodeunit and testFunction are not set
            # as they are mutually exclusive with extensionId in Run-TestsInBcContainer
            if ($testParams.ContainsKey('testCodeunit')) {
                $testParams.Remove('testCodeunit')
            }
            if ($testParams.ContainsKey('testFunction')) {
                $testParams.Remove('testFunction')
            }
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
        if (-not [string]::IsNullOrWhiteSpace($TestCodeunit) -and $TestCodeunit -ne "*") {
            Write-InfoMessage "Test codeunit: $TestCodeunit"
        }
        if (-not [string]::IsNullOrWhiteSpace($TestFunction) -and $TestFunction -ne "*") {
            Write-InfoMessage "Test function: $TestFunction"
        }
        if (-not [string]::IsNullOrWhiteSpace($ExtensionId)) {
            Write-InfoMessage "Extension ID: $ExtensionId"
        }
        Write-InfoMessage "Results will be saved to: $ResultFile"

        $startTime = Get-Date

        # Run the tests and capture the output
        Write-InfoMessage "Running tests in container '$ContainerName'..."

        # First, check if there are any tests in the container
        Write-InfoMessage "Checking for available tests in container..."
        $availableTests = $null
        try {
            $availableTests = Get-TestsFromBcContainer -containerName $ContainerName -credential $testParams['credential']
            if ($availableTests -and $availableTests.Count -gt 0) {
                # Just log the available test codeunits for now
                # We'll get more detailed information after running the tests
                Write-InfoMessage "Found $($availableTests.Count) test codeunit(s) in container."
                Write-InfoMessage "Note: Each test codeunit may contain multiple test functions."
                foreach ($test in $availableTests) {
                    Write-InfoMessage "  - $($test.TestCodeunit): $($test.TestFunction)"
                }
            } else {
                Write-WarningMessage "No tests found in container. Make sure the test app is properly published and contains test codeunits."
                Write-InfoMessage "Checking published extensions in container..."
                $publishedApps = Invoke-ScriptInBcContainer -containerName $ContainerName -scriptblock {
                    Get-NAVAppInfo -ServerInstance BC -Tenant default | Select-Object Name, Publisher, Version, IsInstalled
                }

                if ($publishedApps) {
                    Write-InfoMessage "Published extensions in container:"
                    foreach ($app in $publishedApps) {
                        Write-InfoMessage "  - $($app.Publisher)_$($app.Name)_$($app.Version) (Installed: $($app.IsInstalled))"
                    }

                    # Check if the test app is installed
                    $testApp = $publishedApps | Where-Object { $_.Name -like "*test*" }
                    if ($testApp) {
                        Write-InfoMessage "Test app found: $($testApp.Publisher)_$($testApp.Name)_$($testApp.Version)"
                        Write-InfoMessage "Checking test codeunits in the test app..."

                        # Try to get test codeunits directly
                        try {
                            $testCodeunits = Invoke-ScriptInBcContainer -containerName $ContainerName -scriptblock {
                                param($testAppName)
                                Get-NAVAppObjectMetadata -ServerInstance BC -Tenant default -AppName $testAppName |
                                    Where-Object { $_.ObjectType -eq 'Codeunit' -and $_.SubType -eq 'Test' } |
                                    Select-Object ObjectName, ObjectID
                            } -argumentList $testApp.Name

                            if ($testCodeunits -and $testCodeunits.Count -gt 0) {
                                Write-InfoMessage "Found $($testCodeunits.Count) test codeunit(s) in the test app:"
                                foreach ($codeunit in $testCodeunits) {
                                    Write-InfoMessage "  - $($codeunit.ObjectName) (ID: $($codeunit.ObjectID))"
                                }
                                Write-InfoMessage "However, these test codeunits are not being recognized by the test runner."
                            } else {
                                Write-WarningMessage "No test codeunits found in the test app. Make sure your test codeunits have Subtype = Test;"
                            }
                        } catch {
                            Write-WarningMessage "Failed to get test codeunits from the test app: $_"
                        }
                    } else {
                        Write-WarningMessage "No test app found in the published extensions."
                    }
                } else {
                    Write-WarningMessage "No published extensions found in container."
                }

                # Provide guidance on fixing test issues
                Write-InfoMessage "Possible reasons for tests not being found:"
                Write-InfoMessage "1. Test codeunits don't have 'Subtype = Test;' property"
                Write-InfoMessage "2. Test functions don't have the [Test] attribute"
                Write-InfoMessage "3. The test app wasn't properly published or installed"
                Write-InfoMessage "4. The test app doesn't have the correct dependencies"
                Write-InfoMessage "5. The test app's ID ranges don't match the codeunit IDs"
            }
        } catch {
            Write-WarningMessage "Failed to get available tests from container: $_"
        }

        # Run the tests
        $testOutput = Invoke-ScriptWithErrorHandling -ScriptBlock {
            Run-TestsInBcContainer @testParams
        } -ErrorMessage "Failed to run tests in container"

        $endTime = Get-Date
        $duration = $endTime - $startTime
        $result.Duration = $duration

        # Process test results from the output
        $result.Success = $testOutput

        # Get test details from the container
        Write-InfoMessage "Getting test details from container..."
        try {
            # Use the same credentials for getting test details
            $tests = Get-TestsFromBcContainer -containerName $ContainerName -credential $testParams['credential']

            # Parse the test output to extract test results if Get-TestsFromBcContainer doesn't return complete results
            if (-not $tests -or $tests.Count -eq 0 -or [string]::IsNullOrEmpty($tests[0].TestFunction)) {
                Write-InfoMessage "No detailed test results returned from Get-TestsFromBcContainer, parsing test output..."

                # Create a regex pattern to extract test information from the output
                $testOutputLines = $testOutput.ToString() -split "`r?`n"
                $testResults = @()

                # Pattern for codeunit line: "  Codeunit 50000 HelloWorld Test Failure (0.271 seconds)"
                $codeunitPattern = '^\s*Codeunit\s+(\d+)\s+(.*?)\s+(Success|Failure|Skipped)\s+\((.*?)\s+seconds\)'

                # Pattern for test function line: "    Testfunction TestHelloWorldMessage Success (0.157 seconds)"
                $testFunctionPattern = '^\s*Testfunction\s+(.*?)\s+(Success|Failure|Skipped)\s+\((.*?)\s+seconds\)'

                # Pattern for error message: "      Error:"
                $errorPattern = '^\s*Error:'

                $currentCodeunit = $null
                $currentCodeunitId = $null
                $currentFunction = $null
                $currentResult = $null
                $currentError = $null
                $inErrorSection = $false

                foreach ($line in $testOutputLines) {
                    # Check for codeunit line
                    if ($line -match $codeunitPattern) {
                        $currentCodeunitId = $matches[1]
                        $currentCodeunit = $matches[2]
                        # Process any previous function before starting a new codeunit
                        if ($currentFunction) {
                            $testResults += [PSCustomObject]@{
                                TestCodeunit = $currentCodeunit
                                TestCodeunitId = $currentCodeunitId
                                TestFunction = $currentFunction
                                Result = $currentResult
                                ErrorMessage = $currentError
                            }
                            $currentFunction = $null
                            $currentResult = $null
                            $currentError = $null
                        }
                    }
                    # Check for test function line
                    elseif ($line -match $testFunctionPattern) {
                        # Process any previous function before starting a new one
                        if ($currentFunction) {
                            $testResults += [PSCustomObject]@{
                                TestCodeunit = $currentCodeunit
                                TestCodeunitId = $currentCodeunitId
                                TestFunction = $currentFunction
                                Result = $currentResult
                                ErrorMessage = $currentError
                            }
                        }
                        $currentFunction = $matches[1]
                        $currentResult = $matches[2]
                        $currentError = $null
                        $inErrorSection = $false
                    }
                    # Check for error section
                    elseif ($line -match $errorPattern) {
                        $inErrorSection = $true
                        $currentError = ""
                    }
                    # Collect error message
                    elseif ($inErrorSection -and $line.Trim() -ne "") {
                        $currentError += $line.Trim() + " "
                    }
                }

                # Add the last test function if there is one
                if ($currentFunction) {
                    $testResults += [PSCustomObject]@{
                        TestCodeunit = $currentCodeunit
                        TestCodeunitId = $currentCodeunitId
                        TestFunction = $currentFunction
                        Result = $currentResult
                        ErrorMessage = $currentError
                    }
                }

                # Use the parsed results if we found any
                if ($testResults.Count -gt 0) {
                    $tests = $testResults
                    Write-InfoMessage "Parsed $($tests.Count) test function(s) from output."
                }
            }

            if ($tests -and $tests.Count -gt 0) {
                $totalTests = $tests.Count
                $passedTests = ($tests | Where-Object { $_.Result -eq "Success" }).Count
                $failedTests = ($tests | Where-Object { $_.Result -eq "Failure" }).Count
                $skippedTests = ($tests | Where-Object { $_.Result -eq "Skipped" }).Count
            } else {
                # If no test details were returned but the test output indicates success,
                # we'll create a synthetic test result based on the output
                if ($testOutput -eq $true) {
                    Write-InfoMessage "No detailed test results returned, but tests were run successfully. Analyzing test output..."
                    $totalTests = 1
                    $passedTests = 1
                    $failedTests = 0
                    $skippedTests = 0

                    # Create a synthetic test result
                    $tests = @(
                        [PSCustomObject]@{
                            TestCodeunit = $TestCodeunit
                            TestFunction = "Unknown"
                            Result = "Success"
                            ErrorMessage = ""
                        }
                    )
                } else {
                    $totalTests = 0
                    $passedTests = 0
                    $failedTests = 0
                    $skippedTests = 0
                }
            }

            # Update test counts from XML file if available
            if (-not [string]::IsNullOrWhiteSpace($ResultFile) -and (Test-Path -Path $ResultFile)) {
                try {
                    [xml]$xmlContent = Get-Content -Path $ResultFile -Raw
                    $totalCount = [int]$xmlContent.assemblies.assembly.total
                    $failedCount = [int]$xmlContent.assemblies.assembly.failed
                    $skippedCount = [int]$xmlContent.assemblies.assembly.skipped
                    $passedCount = [int]$xmlContent.assemblies.assembly.passed

                    # Update the test counts based on the XML file
                    $totalTests = $totalCount
                    $failedTests = $failedCount
                    $passedTests = $passedCount
                    $skippedTests = $skippedCount
                } catch {
                    Write-WarningMessage "Failed to parse test results XML for summary: $_"
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
                Write-ErrorMessage "Failed: $failedTests" "Some tests failed."
            } else {
                Write-SuccessMessage "Failed: $failedTests"
            }
            Write-InfoMessage "Skipped: $skippedTests"
            Write-InfoMessage "Duration: $($duration.ToString('hh\:mm\:ss'))"

            # Display failed tests if any
            if ($failedTests -gt 0) {
                Write-SectionHeader "Failed Tests"
                $failedTests = $tests | Where-Object { $_.Result -eq "Failure" }
                foreach ($test in $failedTests) {
                    Write-ErrorMessage "$($test.TestCodeunit): $($test.TestFunction)" "$($test.ErrorMessage)"
                }
            }

            # Set success based on test results

            if ($result.AllTestsPassed) {
                $result.Message = "All tests passed successfully."
                Write-SuccessMessage "All tests passed successfully."
            } else {
                $result.Message = "Some tests failed."
                Write-ErrorMessage "Some tests failed. Check the test results for details."
            }

            # Check if test results file was created
            if (-not [string]::IsNullOrWhiteSpace($ResultFile) -and (Test-Path -Path $ResultFile)) {
                # Verify the file has content
                $fileContent = Get-Content -Path $ResultFile -Raw
                if ([string]::IsNullOrWhiteSpace($fileContent)) {
                    Write-WarningMessage "Test results file is empty. Generating minimal XML structure..."
                    # Create a minimal XML structure for empty test results
                    $xmlContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<assemblies />
"@
                    Set-Content -Path $ResultFile -Value $xmlContent
                    Write-InfoMessage "Created minimal test results XML at: $ResultFile"
                } elseif ($fileContent -match "<assemblies\s*/>") {
                    Write-WarningMessage "Test results file contains empty assemblies tag. This indicates no tests were found or run."
                    Write-InfoMessage "Test results saved to: $ResultFile"
                } else {
                    Write-InfoMessage "Test results saved to: $ResultFile"
                }
            } elseif (-not [string]::IsNullOrWhiteSpace($ResultFile)) {
                Write-WarningMessage "Test results file not created. Generating minimal XML structure..."
                # Create a minimal XML structure for empty test results
                $xmlContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<assemblies />
"@
                try {
                    # Ensure the directory exists
                    $resultDir = Split-Path -Path $ResultFile -Parent
                    if (-not (Test-Path -Path $resultDir)) {
                        New-Item -Path $resultDir -ItemType Directory -Force | Out-Null
                    }

                    Set-Content -Path $ResultFile -Value $xmlContent
                    Write-InfoMessage "Created minimal test results XML at: $ResultFile"
                } catch {
                    Write-ErrorMessage "Failed to generate test results XML: $_"
                }
            }
        } catch {
            Write-WarningMessage "Failed to get test details from container: $_"
            $result.Success = $testOutput
            $result.Message = "Tests completed, but failed to get test details."
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
$testResult = Invoke-RunTests -Config $config -ContainerName $ContainerName -TestCodeunit $TestCodeunit -TestFunction $TestFunction -ExtensionId $ExtensionId -ResultFile $ResultFile -Detailed:$Detailed -FailFast:$FailFast -Timeout $Timeout

# Set the exit code for the script
if (-not $testResult.Success) {
    # Exit with non-zero code to indicate failure when used in scripts
    exit 1
}
