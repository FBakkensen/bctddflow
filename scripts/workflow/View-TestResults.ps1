<#
.SYNOPSIS
    Displays test results from Business Central tests in a readable format.
.DESCRIPTION
    This script formats and displays test results from Business Central tests by:
    1. Taking a parameter for the test results file path with default from configuration
    2. Using Get-TDDConfiguration.ps1 to load configuration settings
    3. Using Common-Functions.ps1 for utility functions
    4. Parsing the XML test results file
    5. Formatting and displaying test results in a readable format
    6. Providing summary statistics (tests run, passed, failed, skipped)
    7. Returning a strongly-typed [pscustomobject] with result summary
    8. Highlighting failed tests with details on why they failed

    The script uses settings from the TDDConfig.psd1 file, including test results path
    and display preferences.
.PARAMETER ConfigPath
    Path to the configuration file. Default is "scripts\TDDConfig.psd1" in the same directory as this script.
.PARAMETER ResultFile
    Path to the test results file. Default is from configuration.
.PARAMETER ShowPassed
    Include this switch to show passed tests in the output. Default is to show only failed tests.
.PARAMETER DetailLevel
    Level of detail to show in the output. Options are "Minimal", "Normal", "Detailed". Default is "Normal".
.EXAMPLE
    .\scripts\View-TestResults.ps1
    # Displays test results using default settings from configuration
.EXAMPLE
    .\scripts\View-TestResults.ps1 -ResultFile ".\TestResults.xml"
    # Displays test results from the specified file
.EXAMPLE
    .\scripts\View-TestResults.ps1 -ShowPassed
    # Displays all test results, including passed tests
.EXAMPLE
    .\scripts\View-TestResults.ps1 -DetailLevel "Detailed"
    # Displays test results with detailed information
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
    [string]$ResultFile,

    [Parameter(Mandatory = $false)]
    [switch]$ShowPassed,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Minimal", "Normal", "Detailed")]
    [string]$DetailLevel = "Normal"
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

function Format-TestDuration {
    <#
    .SYNOPSIS
        Formats a test duration in a human-readable format.
    .DESCRIPTION
        Converts a duration in seconds to a human-readable format.
    .PARAMETER Seconds
        The duration in seconds.
    .OUTPUTS
        System.String. Returns the formatted duration.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [double]$Seconds
    )

    if ($Seconds -lt 0.001) {
        return "<1ms"
    } elseif ($Seconds -lt 1) {
        return "$([math]::Round($Seconds * 1000))ms"
    } elseif ($Seconds -lt 60) {
        return "$([math]::Round($Seconds, 2))s"
    } else {
        $minutes = [math]::Floor($Seconds / 60)
        $remainingSeconds = $Seconds % 60
        return "{0}:{1:00}m" -f $minutes, $remainingSeconds
    }
}

function Get-TestResultSummary {
    <#
    .SYNOPSIS
        Parses a test results XML file and returns a summary.
    .DESCRIPTION
        Reads an XML test results file and returns a summary of the test results.
    .PARAMETER ResultFile
        Path to the test results XML file.
    .OUTPUTS
        PSCustomObject. Returns an object with test result summary information.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResultFile
    )

    # Initialize result object
    $result = [PSCustomObject]@{
        Success = $false
        Message = ""
        TotalTests = 0
        PassedTests = 0
        FailedTests = 0
        SkippedTests = 0
        TestSuites = @()
        TestCases = @()
        Duration = 0
        Timestamp = Get-Date
    }

    try {
        # Check if the file exists
        if (-not (Test-Path -Path $ResultFile)) {
            $result.Message = "Test results file not found: $ResultFile"
            return $result
        }

        # Load the XML file
        [xml]$xml = Get-Content -Path $ResultFile -Raw

        # Check if the XML is valid
        if (-not $xml) {
            $result.Message = "Invalid test results XML file: $ResultFile"
            return $result
        }

        # Process test suites - handle both formats (testsuites and assemblies)
        $testSuites = @()

        # Handle empty assemblies (no tests found)
        if ($xml.assemblies -and -not $xml.assemblies.assembly) {
            # Create a default suite for empty test results
            $suite = [PSCustomObject]@{
                Name = "No Tests Found"
                Tests = 0
                Failures = 0
                Skipped = 0
                Duration = 0
                Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                TestCases = @()
            }
            $testSuites += $suite

            # Add a note about no tests being found
            Write-WarningMessage "No tests were found in the container. Please check that your test app contains test codeunits."
            Write-InfoMessage "Possible reasons for no tests being found:"
            Write-InfoMessage "1. The test app doesn't contain any test codeunits"
            Write-InfoMessage "2. Test codeunits don't have the [TestPermissions] attribute"
            Write-InfoMessage "3. Test functions don't have the [Test] attribute"
            Write-InfoMessage "4. The test app wasn't properly published to the container"
        }
        # Handle Business Central test results format (assemblies with content)
        elseif ($xml.assemblies) {
            foreach ($assembly in $xml.assemblies.assembly) {
                $suite = [PSCustomObject]@{
                    Name = $assembly.name
                    Tests = [int]$assembly.total
                    Failures = [int]$assembly.failed
                    Skipped = [int]$assembly.skipped
                    Duration = [double]$assembly.time
                    Timestamp = "$($assembly.'run-date') $($assembly.'run-time')"
                    TestCases = @()
                }

                # Process test cases from collections
                foreach ($collection in $assembly.collection) {
                    foreach ($testCase in $collection.test) {
                        $case = [PSCustomObject]@{
                            Name = $testCase.method
                            ClassName = $collection.name
                            Duration = [double]$testCase.time
                            Result = if ($testCase.result -eq "Pass") { "Success" } else { $testCase.result }
                            ErrorMessage = ""
                        }

                        # Check for failures
                        if ($testCase.failure) {
                            $case.Result = "Failure"
                            $case.ErrorMessage = $testCase.failure.message
                        }

                        # Check for skipped tests
                        if ($testCase.result -eq "Skip") {
                            $case.Result = "Skipped"
                        }

                        $suite.TestCases += $case
                        $result.TestCases += $case
                    }
                }

                $testSuites += $suite
            }
        }
        # Handle standard xUnit format (testsuites)
        elseif ($xml.testsuites) {
            foreach ($testSuite in $xml.testsuites.testsuite) {
                $suite = [PSCustomObject]@{
                    Name = $testSuite.name
                    Tests = [int]$testSuite.tests
                    Failures = [int]$testSuite.failures
                    Skipped = [int]$testSuite.skipped
                    Duration = [double]$testSuite.time
                    Timestamp = $testSuite.timestamp
                    TestCases = @()
                }

                # Process test cases
                foreach ($testCase in $testSuite.testcase) {
                    $case = [PSCustomObject]@{
                        Name = $testCase.name
                        ClassName = $testCase.classname
                        Duration = [double]$testCase.time
                        Result = "Success"
                        ErrorMessage = ""
                    }

                    # Check for failures
                    if ($testCase.failure) {
                        $case.Result = "Failure"
                        $case.ErrorMessage = $testCase.failure.message
                    }

                    # Check for skipped tests
                    if ($testCase.skipped) {
                        $case.Result = "Skipped"
                    }

                    $suite.TestCases += $case
                    $result.TestCases += $case
                }

                $testSuites += $suite
            }
        }
        else {
            $result.Message = "Unsupported test results XML format: $ResultFile"
            return $result
        }

        $result.TestSuites = $testSuites

        # Calculate summary statistics
        $result.TotalTests = $result.TestCases.Count
        $result.PassedTests = ($result.TestCases | Where-Object { $_.Result -eq "Success" }).Count
        $result.FailedTests = ($result.TestCases | Where-Object { $_.Result -eq "Failure" }).Count
        $result.SkippedTests = ($result.TestCases | Where-Object { $_.Result -eq "Skipped" }).Count
        $result.Duration = ($result.TestSuites | Measure-Object -Property Duration -Sum).Sum

        $result.Success = $true
        $result.Message = "Test results parsed successfully."
    }
    catch {
        $result.Message = "Error parsing test results: $_"
    }

    return $result
}

function Invoke-ViewTestResult {
    <#
    .SYNOPSIS
        Main function to view test results.
    .DESCRIPTION
        Parses and displays test results in a readable format.
    .PARAMETER Config
        The configuration object.
    .PARAMETER ResultFile
        Path to the test results file.
    .PARAMETER ShowPassed
        Whether to show passed tests in the output.
    .PARAMETER DetailLevel
        Level of detail to show in the output.
    .OUTPUTS
        PSCustomObject. Returns an object with the results of the operation.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $false)]
        [string]$ResultFile,

        [Parameter(Mandatory = $false)]
        [bool]$ShowPassed,

        [Parameter(Mandatory = $false)]
        [string]$DetailLevel
    )

    # Initialize result object
    $result = [PSCustomObject]@{
        Success = $false
        Message = ""
        ResultFile = $null
        TotalTests = 0
        PassedTests = 0
        FailedTests = 0
        SkippedTests = 0
        Duration = 0
        AllTestsPassed = $false
        Timestamp = Get-Date
    }

    try {
        # Validate result file path
        if ([string]::IsNullOrWhiteSpace($ResultFile)) {
            $testResultsDir = Resolve-TDDPath -Path $Config.OutputPaths.TestResults
            $ResultFile = Join-Path -Path $testResultsDir -ChildPath "TestResults.xml"
        }
        $result.ResultFile = $ResultFile

        # Display section header
        Write-SectionHeader "Test Results" -ForegroundColor Cyan -DecorationType Box

        # Display information about the operation
        Write-InfoMessage "Viewing test results from: $ResultFile"
        Write-InfoMessage "Detail Level: $DetailLevel"
        Write-InfoMessage "Show Passed Tests: $ShowPassed"

        # Parse the test results
        $testResults = Get-TestResultSummary -ResultFile $ResultFile

        if (-not $testResults.Success) {
            Write-ErrorMessage $testResults.Message
            $result.Message = $testResults.Message
            return $result
        }

        # Update result object with test summary
        $result.TotalTests = $testResults.TotalTests
        $result.PassedTests = $testResults.PassedTests
        $result.FailedTests = $testResults.FailedTests
        $result.SkippedTests = $testResults.SkippedTests
        $result.Duration = $testResults.Duration
        $result.AllTestsPassed = ($testResults.FailedTests -eq 0)

        # Display test summary
        Write-SectionHeader "Test Summary" -ForegroundColor White -DecorationType Underline
        Write-InfoMessage "Total Tests: $($result.TotalTests)"
        Write-InfoMessage "Passed: $($result.PassedTests)"

        if ($result.FailedTests -gt 0) {
            Write-ErrorMessage "Failed: $($result.FailedTests)"
        } else {
            Write-InfoMessage "Failed: $($result.FailedTests)"
        }

        Write-InfoMessage "Skipped: $($result.SkippedTests)"
        Write-InfoMessage "Duration: $(Format-TestDuration $result.Duration)"

        # Display test suites
        if ($DetailLevel -ne "Minimal") {
            Write-SectionHeader "Test Suites" -ForegroundColor White -DecorationType Underline

            foreach ($suite in $testResults.TestSuites) {
                $suiteColor = if ($suite.Failures -gt 0) { "Red" } else { "Green" }
                $suiteStatus = if ($suite.Failures -gt 0) { "FAILED" } else { "PASSED" }

                Write-Host "$($suite.Name) [$suiteStatus] - $($suite.Tests) tests, $($suite.Failures) failures, $(Format-TestDuration $suite.Duration)" -ForegroundColor $suiteColor

                # Display test cases
                if ($DetailLevel -eq "Detailed" -or ($suite.Failures -gt 0 -and $DetailLevel -eq "Normal")) {
                    foreach ($case in $suite.TestCases) {
                        # Skip passed tests if not showing passed
                        if (-not $ShowPassed -and $case.Result -eq "Success") {
                            continue
                        }

                        $caseColor = switch ($case.Result) {
                            "Success" { "Green" }
                            "Failure" { "Red" }
                            "Skipped" { "Yellow" }
                            default { "White" }
                        }

                        $indent = "  "
                        Write-Host "$indent$($case.Name) - $($case.Result) ($(Format-TestDuration $case.Duration))" -ForegroundColor $caseColor

                        # Display error message for failed tests
                        if ($case.Result -eq "Failure" -and -not [string]::IsNullOrWhiteSpace($case.ErrorMessage)) {
                            Write-Host "$indent$indent$($case.ErrorMessage)" -ForegroundColor Red
                        }
                    }
                }
            }
        }

        # Display failed tests
        if ($result.FailedTests -gt 0) {
            Write-SectionHeader "Failed Tests" -ForegroundColor Red -DecorationType Underline

            $failedTests = $testResults.TestCases | Where-Object { $_.Result -eq "Failure" }
            foreach ($test in $failedTests) {
                Write-ErrorMessage "$($test.ClassName): $($test.Name)" "$($test.ErrorMessage)"
            }
        }

        # Set success based on test results
        $result.Success = $true

        if ($result.AllTestsPassed) {
            $result.Message = "All tests passed successfully."
            Write-SuccessMessage "All tests passed successfully."
        } else {
            $result.Message = "Some tests failed."
            Write-ErrorMessage "Some tests failed. Check the test results for details."
        }

        return $result
    }
    catch {
        $errorMessage = "Error viewing test results: $_"
        Write-ErrorMessage $errorMessage
        $result.Success = $false
        $result.Message = $errorMessage
        return $result
    }
}

#endregion

#region Main Script Execution

# Apply TDD session settings from configuration if available
if ($config.TDDSession) {
    if (-not $PSBoundParameters.ContainsKey('ShowPassed') -and $null -ne $config.TDDSession.ShowPassedTests) {
        $ShowPassed = $config.TDDSession.ShowPassedTests
    }

    if (-not $PSBoundParameters.ContainsKey('DetailLevel') -and -not [string]::IsNullOrWhiteSpace($config.TDDSession.DetailLevel)) {
        $DetailLevel = $config.TDDSession.DetailLevel
    }
}

# Execute the main function
$result = Invoke-ViewTestResult -Config $config -ResultFile $ResultFile -ShowPassed $ShowPassed -DetailLevel $DetailLevel

# Return the result
return $result

#endregion
