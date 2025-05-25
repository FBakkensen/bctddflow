<#
.SYNOPSIS
    Provides an interactive menu-driven interface for the Business Central TDD workflow.
.DESCRIPTION
    This script provides a menu-driven interface for the Business Central TDD workflow with options to:
    1. Initialize the environment by calling Initialize-TDDEnvironment.ps1
    2. Compile main app
    3. Compile test app
    4. Deploy main app
    5. Deploy test app
    6. Run all tests
    7. Run specific tests
    8. View test results
    9. Edit configuration settings
    10. Exit the session

    The script maintains state between commands according to configuration and provides
    clear feedback after each action.

    This script uses common utility functions from Common-Functions.ps1 and configuration
    from TDDConfig.psd1 for consistent functionality across the TDD workflow scripts.
.PARAMETER ConfigPath
    Path to the configuration file. Default is "scripts\TDDConfig.psd1" in the same directory as this script.
.EXAMPLE
    .\scripts\Start-TDDSession.ps1
    # Starts an interactive TDD session with default configuration
.EXAMPLE
    .\scripts\Start-TDDSession.ps1 -ConfigPath "C:\MyProject\CustomConfig.psd1"
    # Starts an interactive TDD session with a custom configuration file
.NOTES
    This script is part of the Business Central TDD workflow.

    Author: AI Assistant
    Date: 2023-11-16
    Version: 1.0

    Change Log:
    1.0 - Initial version
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath
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
$commonFunctionsPath = Join-Path -Path $scriptDir -ChildPath "lib\Common-Functions.ps1"
if (-not (Test-Path -Path $commonFunctionsPath)) {
    Write-Error "Common-Functions.ps1 not found at path: $commonFunctionsPath. Make sure the script exists in the lib folder."
    exit 1
}
. $commonFunctionsPath

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

# Initialize session state
$sessionState = [PSCustomObject]@{
    LastAction = $null
    LastActionTime = $null
    LastActionResult = $null
    LastTestCodeunit = "*"
    LastTestFunction = "*"
    LastExtensionId = ""
    MainAppCompiled = $false
    TestAppCompiled = $false
    MainAppDeployed = $false
    TestAppDeployed = $false
    TestsRun = $false
    EnvironmentInitialized = $false
}

#endregion

#region Menu Functions

function Show-MainMenu {
    <#
    .SYNOPSIS
        Displays the main menu for the TDD session.
    .DESCRIPTION
        Shows the available options for the TDD workflow and prompts for user input.
    .OUTPUTS
        System.String. Returns the selected menu option.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    Clear-Host

    Write-SectionHeader "Business Central TDD Session" -ForegroundColor Cyan -DecorationType Box

    # Display session state if applicable
    if ($sessionState.LastAction) {
        Write-Host "Last Action: $($sessionState.LastAction) at $($sessionState.LastActionTime)" -ForegroundColor Yellow

        if ($sessionState.LastActionResult) {
            $resultColor = if ($sessionState.LastActionResult.Success) { "Green" } else { "Red" }
            Write-Host "Result: $($sessionState.LastActionResult.Message)" -ForegroundColor $resultColor
        }

        Write-Host ""
    }

    # Display environment status
    Write-Host "Environment Status:" -ForegroundColor Cyan
    Write-Host "  Container: $($config.ContainerName)" -ForegroundColor $(if ($sessionState.EnvironmentInitialized) { "Green" } else { "Gray" })
    Write-Host "  Main App: $(if ($sessionState.MainAppCompiled) { "Compiled" } else { "Not Compiled" })" -ForegroundColor $(if ($sessionState.MainAppCompiled) { "Green" } else { "Gray" })
    Write-Host "  Test App: $(if ($sessionState.TestAppCompiled) { "Compiled" } else { "Not Compiled" })" -ForegroundColor $(if ($sessionState.TestAppCompiled) { "Green" } else { "Gray" })
    Write-Host "  Main App Deployed: $(if ($sessionState.MainAppDeployed) { "Yes" } else { "No" })" -ForegroundColor $(if ($sessionState.MainAppDeployed) { "Green" } else { "Gray" })
    Write-Host "  Test App Deployed: $(if ($sessionState.TestAppDeployed) { "Yes" } else { "No" })" -ForegroundColor $(if ($sessionState.TestAppDeployed) { "Green" } else { "Gray" })
    Write-Host "  Tests Run: $(if ($sessionState.TestsRun) { "Yes" } else { "No" })" -ForegroundColor $(if ($sessionState.TestsRun) { "Green" } else { "Gray" })
    Write-Host ""

    # Display menu options
    Write-Host "Menu Options:" -ForegroundColor Cyan
    Write-Host "  [1] Initialize Environment" -ForegroundColor $(if (-not $sessionState.EnvironmentInitialized) { "Yellow" } else { "White" })
    Write-Host "  [2] Compile Main App" -ForegroundColor $(if (-not $sessionState.MainAppCompiled) { "Yellow" } else { "White" })
    Write-Host "  [3] Compile Test App" -ForegroundColor $(if (-not $sessionState.TestAppCompiled) { "Yellow" } else { "White" })
    Write-Host "  [4] Deploy Main App" -ForegroundColor $(if ($sessionState.MainAppCompiled -and -not $sessionState.MainAppDeployed) { "Yellow" } else { "White" })
    Write-Host "  [5] Deploy Test App" -ForegroundColor $(if ($sessionState.TestAppCompiled -and -not $sessionState.TestAppDeployed) { "Yellow" } else { "White" })
    Write-Host "  [6] Run All Tests" -ForegroundColor $(if ($sessionState.MainAppDeployed -and $sessionState.TestAppDeployed) { "Yellow" } else { "White" })
    Write-Host "  [7] Run Specific Tests" -ForegroundColor $(if ($sessionState.MainAppDeployed -and $sessionState.TestAppDeployed) { "Yellow" } else { "White" })
    Write-Host "  [8] View Test Results" -ForegroundColor $(if ($sessionState.TestsRun) { "Yellow" } else { "White" })
    Write-Host "  [9] Edit Configuration Settings" -ForegroundColor White
    Write-Host "  [0] Exit Session" -ForegroundColor White
    Write-Host ""

    # Prompt for selection
    $selection = Read-Host "Enter your selection (0-9)"
    return $selection
}

#endregion

#region Action Functions

function Initialize-Environment {
    <#
    .SYNOPSIS
        Initializes the Business Central TDD environment.
    .DESCRIPTION
        Calls Initialize-TDDEnvironment.ps1 to set up the environment.
    .OUTPUTS
        PSCustomObject. Returns an object with the results of the operation.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $result = [PSCustomObject]@{
        Success = $false
        Message = ""
        Data = $null
    }

    try {
        Write-SectionHeader "Initializing Environment" -ForegroundColor Cyan -DecorationType Underline

        $initEnvPath = Join-Path -Path $scriptDir -ChildPath "Initialize-TDDEnvironment.ps1"
        if (-not (Test-Path -Path $initEnvPath)) {
            throw "Initialize-TDDEnvironment.ps1 not found at path: $initEnvPath"
        }

        $initParams = @{}
        if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
            $initParams['ConfigPath'] = $ConfigPath
        }

        & $initEnvPath @initParams

        # Check if the environment was initialized successfully
        if ($LASTEXITCODE -ne 0) {
            throw "Environment initialization failed. Please check the error messages and try again."
        }

        $result.Success = $true
        $result.Message = "Environment initialized successfully."
        $sessionState.EnvironmentInitialized = $true

        Write-SuccessMessage $result.Message
    }
    catch {
        $result.Success = $false
        $result.Message = "Failed to initialize environment: $_"
        Write-ErrorMessage $result.Message
    }

    return $result
}

function Compile-MainApp {
    <#
    .SYNOPSIS
        Prepares and compiles the main Business Central app.
    .DESCRIPTION
        Calls Prepare-AppSource.ps1 to prepare the source code and then
        calls Compile-App.ps1 to compile the main app.
    .OUTPUTS
        PSCustomObject. Returns an object with the results of the operation.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $result = [PSCustomObject]@{
        Success = $false
        Message = ""
        Data = $null
    }

    try {
        Write-SectionHeader "Compiling Main App" -ForegroundColor Cyan -DecorationType Underline

        # First, prepare the source code
        Write-InfoMessage "Preparing source code for main app..."
        $prepareAppPath = Join-Path -Path $scriptDir -ChildPath "Prepare-AppSource.ps1"
        if (-not (Test-Path -Path $prepareAppPath)) {
            throw "Prepare-AppSource.ps1 not found at path: $prepareAppPath"
        }

        $prepareParams = @{
            AppType = "Main"
        }

        if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
            $prepareParams['ConfigPath'] = $ConfigPath
        }

        $prepareResult = & $prepareAppPath @prepareParams

        if (-not $prepareResult -or -not $prepareResult.Success) {
            throw "Failed to prepare main app source: $($prepareResult.Message)"
        }

        Write-SuccessMessage "Main app source prepared successfully."

        # Then, compile the app
        $compileAppPath = Join-Path -Path $scriptDir -ChildPath "workflow\Compile-App.ps1"
        if (-not (Test-Path -Path $compileAppPath)) {
            throw "Compile-App.ps1 not found at path: $compileAppPath"
        }

        $compileParams = @{
            AppType = "Main"
        }

        if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
            $compileParams['ConfigPath'] = $ConfigPath
        }

        $compileResult = & $compileAppPath @compileParams

        if (-not $compileResult -or -not $compileResult.Success) {
            throw "Failed to compile main app: $($compileResult.Message)"
        }

        $result.Success = $true
        $result.Message = "Main app compiled successfully."
        $result.Data = $compileResult
        $sessionState.MainAppCompiled = $true

        Write-SuccessMessage $result.Message
    }
    catch {
        $result.Success = $false
        $result.Message = "Failed to compile main app: $_"
        Write-ErrorMessage $result.Message
    }

    return $result
}

function Compile-TestApp {
    <#
    .SYNOPSIS
        Prepares and compiles the Business Central test app.
    .DESCRIPTION
        Calls Prepare-AppSource.ps1 to prepare the source code and then
        calls Compile-App.ps1 to compile the test app.
    .OUTPUTS
        PSCustomObject. Returns an object with the results of the operation.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $result = [PSCustomObject]@{
        Success = $false
        Message = ""
        Data = $null
    }

    try {
        Write-SectionHeader "Compiling Test App" -ForegroundColor Cyan -DecorationType Underline

        # First, prepare the source code
        Write-InfoMessage "Preparing source code for test app..."
        $prepareAppPath = Join-Path -Path $scriptDir -ChildPath "workflow\Prepare-AppSource.ps1"
        if (-not (Test-Path -Path $prepareAppPath)) {
            throw "Prepare-AppSource.ps1 not found at path: $prepareAppPath"
        }

        $prepareParams = @{
            AppType = "Test"
        }

        if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
            $prepareParams['ConfigPath'] = $ConfigPath
        }

        $prepareResult = & $prepareAppPath @prepareParams

        if (-not $prepareResult -or -not $prepareResult.Success) {
            throw "Failed to prepare test app source: $($prepareResult.Message)"
        }

        Write-SuccessMessage "Test app source prepared successfully."

        # Then, compile the app
        $compileAppPath = Join-Path -Path $scriptDir -ChildPath "workflow\Compile-App.ps1"
        if (-not (Test-Path -Path $compileAppPath)) {
            throw "Compile-App.ps1 not found at path: $compileAppPath"
        }

        $compileParams = @{
            AppType = "Test"
        }

        if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
            $compileParams['ConfigPath'] = $ConfigPath
        }

        $compileResult = & $compileAppPath @compileParams

        if (-not $compileResult -or -not $compileResult.Success) {
            throw "Failed to compile test app: $($compileResult.Message)"
        }

        $result.Success = $true
        $result.Message = "Test app compiled successfully."
        $result.Data = $compileResult
        $sessionState.TestAppCompiled = $true

        Write-SuccessMessage $result.Message
    }
    catch {
        $result.Success = $false
        $result.Message = "Failed to compile test app: $_"
        Write-ErrorMessage $result.Message
    }

    return $result
}

function Deploy-MainApp {
    <#
    .SYNOPSIS
        Deploys the main Business Central app to the container.
    .DESCRIPTION
        Calls Deploy-App.ps1 to deploy the main app to the container.
    .OUTPUTS
        PSCustomObject. Returns an object with the results of the operation.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $result = [PSCustomObject]@{
        Success = $false
        Message = ""
        Data = $null
    }

    try {
        Write-SectionHeader "Deploying Main App" -ForegroundColor Cyan -DecorationType Underline

        # Check if the main app is compiled
        if (-not $sessionState.MainAppCompiled) {
            $compileResult = Compile-MainApp
            if (-not $compileResult.Success) {
                throw "Main app must be compiled before deployment. Compilation failed."
            }
        }

        $deployAppPath = Join-Path -Path $scriptDir -ChildPath "workflow\Deploy-App.ps1"
        if (-not (Test-Path -Path $deployAppPath)) {
            throw "Deploy-App.ps1 not found at path: $deployAppPath"
        }

        $deployParams = @{
            AppType = "Main"
            ContainerName = $config.ContainerName
        }

        if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
            $deployParams['ConfigPath'] = $ConfigPath
        }

        $deployResult = & $deployAppPath @deployParams

        if (-not $deployResult -or -not $deployResult.Success) {
            throw "Failed to deploy main app: $($deployResult.Message)"
        }

        $result.Success = $true
        $result.Message = "Main app deployed successfully."
        $result.Data = $deployResult
        $sessionState.MainAppDeployed = $true

        Write-SuccessMessage $result.Message
    }
    catch {
        $result.Success = $false
        $result.Message = "Failed to deploy main app: $_"
        Write-ErrorMessage $result.Message
    }

    return $result
}

function Deploy-TestApp {
    <#
    .SYNOPSIS
        Deploys the Business Central test app to the container.
    .DESCRIPTION
        Calls Deploy-App.ps1 to deploy the test app to the container.
    .OUTPUTS
        PSCustomObject. Returns an object with the results of the operation.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $result = [PSCustomObject]@{
        Success = $false
        Message = ""
        Data = $null
    }

    try {
        Write-SectionHeader "Deploying Test App" -ForegroundColor Cyan -DecorationType Underline

        # Check if the test app is compiled
        if (-not $sessionState.TestAppCompiled) {
            $compileResult = Compile-TestApp
            if (-not $compileResult.Success) {
                throw "Test app must be compiled before deployment. Compilation failed."
            }
        }

        # Check if the main app is deployed
        if (-not $sessionState.MainAppDeployed) {
            $deployMainResult = Deploy-MainApp
            if (-not $deployMainResult.Success) {
                throw "Main app must be deployed before test app. Main app deployment failed."
            }
        }

        $deployAppPath = Join-Path -Path $scriptDir -ChildPath "workflow\Deploy-App.ps1"
        if (-not (Test-Path -Path $deployAppPath)) {
            throw "Deploy-App.ps1 not found at path: $deployAppPath"
        }

        $deployParams = @{
            AppType = "Test"
            ContainerName = $config.ContainerName
        }

        if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
            $deployParams['ConfigPath'] = $ConfigPath
        }

        $deployResult = & $deployAppPath @deployParams

        if (-not $deployResult -or -not $deployResult.Success) {
            throw "Failed to deploy test app: $($deployResult.Message)"
        }

        $result.Success = $true
        $result.Message = "Test app deployed successfully."
        $result.Data = $deployResult
        $sessionState.TestAppDeployed = $true

        Write-SuccessMessage $result.Message
    }
    catch {
        $result.Success = $false
        $result.Message = "Failed to deploy test app: $_"
        Write-ErrorMessage $result.Message
    }

    return $result
}

function Run-AllTests {
    <#
    .SYNOPSIS
        Runs all tests in the Business Central test app.
    .DESCRIPTION
        Calls Run-Tests.ps1 to run all tests in the test app.
    .OUTPUTS
        PSCustomObject. Returns an object with the results of the operation.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $result = [PSCustomObject]@{
        Success = $false
        Message = ""
        Data = $null
    }

    try {
        Write-SectionHeader "Running All Tests" -ForegroundColor Cyan -DecorationType Underline

        # Check if the test app is deployed
        if (-not $sessionState.TestAppDeployed) {
            $deployTestResult = Deploy-TestApp
            if (-not $deployTestResult.Success) {
                throw "Test app must be deployed before running tests. Test app deployment failed."
            }
        }

        $runTestsPath = Join-Path -Path $scriptDir -ChildPath "workflow\Run-Tests.ps1"
        if (-not (Test-Path -Path $runTestsPath)) {
            throw "Run-Tests.ps1 not found at path: $runTestsPath"
        }

        $runTestsParams = @{
            ContainerName = $config.ContainerName
        }

        if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
            $runTestsParams['ConfigPath'] = $ConfigPath
        }

        $runTestsResult = & $runTestsPath @runTestsParams

        if (-not $runTestsResult) {
            throw "Failed to run tests. Please check the error messages and try again."
        }

        $result.Success = $runTestsResult.Success
        $result.Message = if ($runTestsResult.Success) { "All tests passed successfully." } else { "Some tests failed. See test results for details." }
        $result.Data = $runTestsResult
        $sessionState.TestsRun = $true

        if ($result.Success) {
            Write-SuccessMessage $result.Message
        } else {
            Write-WarningMessage $result.Message
        }
    }
    catch {
        $result.Success = $false
        $result.Message = "Failed to run tests: $_"
        Write-ErrorMessage $result.Message
    }

    return $result
}

function Run-SpecificTests {
    <#
    .SYNOPSIS
        Runs specific tests in the Business Central test app.
    .DESCRIPTION
        Calls Run-Tests.ps1 to run specific tests in the test app.
    .OUTPUTS
        PSCustomObject. Returns an object with the results of the operation.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $result = [PSCustomObject]@{
        Success = $false
        Message = ""
        Data = $null
    }

    try {
        Write-SectionHeader "Running Specific Tests" -ForegroundColor Cyan -DecorationType Underline

        # Check if the test app is deployed
        if (-not $sessionState.TestAppDeployed) {
            $deployTestResult = Deploy-TestApp
            if (-not $deployTestResult.Success) {
                throw "Test app must be deployed before running tests. Test app deployment failed."
            }
        }

        # Prompt for test parameters
        Write-Host "Enter test parameters (leave blank to use defaults):" -ForegroundColor Cyan
        $testCodeunit = Read-Host "Test Codeunit (default: $($sessionState.LastTestCodeunit))"
        $testFunction = Read-Host "Test Function (default: $($sessionState.LastTestFunction))"
        $extensionId = Read-Host "Extension ID (default: $($sessionState.LastExtensionId))"

        # Use defaults if not provided
        if ([string]::IsNullOrWhiteSpace($testCodeunit)) {
            $testCodeunit = $sessionState.LastTestCodeunit
        } else {
            $sessionState.LastTestCodeunit = $testCodeunit
        }

        if ([string]::IsNullOrWhiteSpace($testFunction)) {
            $testFunction = $sessionState.LastTestFunction
        } else {
            $sessionState.LastTestFunction = $testFunction
        }

        if ([string]::IsNullOrWhiteSpace($extensionId)) {
            $extensionId = $sessionState.LastExtensionId
        } else {
            $sessionState.LastExtensionId = $extensionId
        }

        $runTestsPath = Join-Path -Path $scriptDir -ChildPath "workflow\Run-Tests.ps1"
        if (-not (Test-Path -Path $runTestsPath)) {
            throw "Run-Tests.ps1 not found at path: $runTestsPath"
        }

        $runTestsParams = @{
            ContainerName = $config.ContainerName
            TestCodeunit = $testCodeunit
            TestFunction = $testFunction
        }

        if (-not [string]::IsNullOrWhiteSpace($extensionId)) {
            $runTestsParams['ExtensionId'] = $extensionId
        }

        if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
            $runTestsParams['ConfigPath'] = $ConfigPath
        }

        $runTestsResult = & $runTestsPath @runTestsParams

        if (-not $runTestsResult) {
            throw "Failed to run tests. Please check the error messages and try again."
        }

        $result.Success = $runTestsResult.Success
        $result.Message = if ($runTestsResult.Success) { "All tests passed successfully." } else { "Some tests failed. See test results for details." }
        $result.Data = $runTestsResult
        $sessionState.TestsRun = $true

        if ($result.Success) {
            Write-SuccessMessage $result.Message
        } else {
            Write-WarningMessage $result.Message
        }
    }
    catch {
        $result.Success = $false
        $result.Message = "Failed to run tests: $_"
        Write-ErrorMessage $result.Message
    }

    return $result
}

function View-TestResults {
    <#
    .SYNOPSIS
        Views the results of the last test run.
    .DESCRIPTION
        Calls View-TestResults.ps1 to display the test results.
    .OUTPUTS
        PSCustomObject. Returns an object with the results of the operation.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $result = [PSCustomObject]@{
        Success = $false
        Message = ""
        Data = $null
    }

    try {
        Write-SectionHeader "Viewing Test Results" -ForegroundColor Cyan -DecorationType Underline

        # Check if tests have been run
        if (-not $sessionState.TestsRun) {
            Write-WarningMessage "No tests have been run yet. Running all tests first..."
            $runTestsResult = Run-AllTests
            if (-not $runTestsResult.Success) {
                throw "Failed to run tests. Cannot view test results."
            }
        }

        $viewResultsPath = Join-Path -Path $scriptDir -ChildPath "workflow\View-TestResults.ps1"
        if (-not (Test-Path -Path $viewResultsPath)) {
            throw "View-TestResults.ps1 not found at path: $viewResultsPath"
        }

        $viewResultsParams = @{
            ShowPassed = $config.TDDSession.ShowPassedTests
        }

        if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
            $viewResultsParams['ConfigPath'] = $ConfigPath
        }

        $viewResultsResult = & $viewResultsPath @viewResultsParams

        if (-not $viewResultsResult) {
            throw "Failed to view test results. Please check the error messages and try again."
        }

        $result.Success = $true
        $result.Message = "Test results displayed successfully."
        $result.Data = $viewResultsResult

        Write-SuccessMessage $result.Message
    }
    catch {
        $result.Success = $false
        $result.Message = "Failed to view test results: $_"
        Write-ErrorMessage $result.Message
    }

    return $result
}

function Edit-Configuration {
    <#
    .SYNOPSIS
        Edits the TDD configuration settings.
    .DESCRIPTION
        Provides a menu to edit the TDD configuration settings.
    .OUTPUTS
        PSCustomObject. Returns an object with the results of the operation.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $result = [PSCustomObject]@{
        Success = $false
        Message = ""
        Data = $null
    }

    try {
        Write-SectionHeader "Editing Configuration Settings" -ForegroundColor Cyan -DecorationType Underline

        # Display current configuration
        Write-Host "Current Configuration Settings:" -ForegroundColor Cyan
        Write-Host "  Container Name: $($config.ContainerName)"
        Write-Host "  Main App Source: $($config.SourcePaths.App)"
        Write-Host "  Test App Source: $($config.SourcePaths.Test)"
        Write-Host "  Show Passed Tests: $($config.TDDSession.ShowPassedTests)"
        Write-Host "  Detail Level: $($config.TDDSession.DetailLevel)"
        Write-Host ""

        # Prompt for which setting to edit
        Write-Host "Select a setting to edit:" -ForegroundColor Cyan
        Write-Host "  [1] Container Name"
        Write-Host "  [2] Main App Source Path"
        Write-Host "  [3] Test App Source Path"
        Write-Host "  [4] Show Passed Tests"
        Write-Host "  [5] Detail Level"
        Write-Host "  [0] Return to Main Menu"
        Write-Host ""

        $selection = Read-Host "Enter your selection (0-5)"

        switch ($selection) {
            "0" {
                # Return to main menu
                $result.Success = $true
                $result.Message = "No changes made to configuration."
                return $result
            }
            "1" {
                # Edit Container Name
                $newValue = Read-Host "Enter new Container Name (current: $($config.ContainerName))"
                if (-not [string]::IsNullOrWhiteSpace($newValue)) {
                    $config.ContainerName = $newValue
                    $result.Message = "Container Name updated to: $newValue"
                }
            }
            "2" {
                # Edit Main App Source Path
                $newValue = Read-Host "Enter new Main App Source Path (current: $($config.SourcePaths.App))"
                if (-not [string]::IsNullOrWhiteSpace($newValue)) {
                    $config.SourcePaths.App = $newValue
                    $result.Message = "Main App Source Path updated to: $newValue"
                }
            }
            "3" {
                # Edit Test App Source Path
                $newValue = Read-Host "Enter new Test App Source Path (current: $($config.SourcePaths.Test))"
                if (-not [string]::IsNullOrWhiteSpace($newValue)) {
                    $config.SourcePaths.Test = $newValue
                    $result.Message = "Test App Source Path updated to: $newValue"
                }
            }
            "4" {
                # Edit Show Passed Tests
                $newValue = Read-Host "Show Passed Tests? (true/false) (current: $($config.TDDSession.ShowPassedTests))"
                if (-not [string]::IsNullOrWhiteSpace($newValue)) {
                    $boolValue = $false
                    if ([bool]::TryParse($newValue, [ref]$boolValue)) {
                        $config.TDDSession.ShowPassedTests = $boolValue
                        $result.Message = "Show Passed Tests updated to: $boolValue"
                    } else {
                        Write-WarningMessage "Invalid value. Please enter 'true' or 'false'."
                    }
                }
            }
            "5" {
                # Edit Detail Level
                Write-Host "Available Detail Levels: Basic, Detailed, Verbose" -ForegroundColor Cyan
                $newValue = Read-Host "Enter new Detail Level (current: $($config.TDDSession.DetailLevel))"
                if (-not [string]::IsNullOrWhiteSpace($newValue)) {
                    $validLevels = @("Basic", "Detailed", "Verbose")
                    if ($validLevels -contains $newValue) {
                        $config.TDDSession.DetailLevel = $newValue
                        $result.Message = "Detail Level updated to: $newValue"
                    } else {
                        Write-WarningMessage "Invalid value. Please enter one of: Basic, Detailed, Verbose"
                    }
                }
            }
            default {
                Write-WarningMessage "Invalid selection. Please enter a number between 0 and 5."
                $result.Success = $false
                $result.Message = "No changes made to configuration."
                return $result
            }
        }

        # Configuration was updated
        $result.Success = $true
        if ([string]::IsNullOrWhiteSpace($result.Message)) {
            $result.Message = "Configuration updated successfully."
        }

        Write-SuccessMessage $result.Message
    }
    catch {
        $result.Success = $false
        $result.Message = "Failed to edit configuration: $_"
        Write-ErrorMessage $result.Message
    }

    return $result
}

#endregion

#region Main Script Execution

function Start-TDDSession {
    <#
    .SYNOPSIS
        Starts an interactive TDD session.
    .DESCRIPTION
        Provides a menu-driven interface for the TDD workflow.
    .OUTPUTS
        PSCustomObject. Returns an object with the results of the session.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $result = [PSCustomObject]@{
        Success = $true
        Message = "TDD session completed successfully."
        Actions = @()
    }

    try {
        $exit = $false

        while (-not $exit) {
            $selection = Show-MainMenu

            switch ($selection) {
                "0" {
                    # Exit Session
                    $exit = $true
                    Write-InfoMessage "Exiting TDD session..."
                }
                "1" {
                    # Initialize Environment
                    $actionResult = Initialize-Environment
                    $sessionState.LastAction = "Initialize Environment"
                    $sessionState.LastActionTime = Get-Date
                    $sessionState.LastActionResult = $actionResult
                    $result.Actions += [PSCustomObject]@{
                        Action = $sessionState.LastAction
                        Time = $sessionState.LastActionTime
                        Result = $actionResult
                    }
                }
                "2" {
                    # Compile Main App
                    $actionResult = Compile-MainApp
                    $sessionState.LastAction = "Compile Main App"
                    $sessionState.LastActionTime = Get-Date
                    $sessionState.LastActionResult = $actionResult
                    $result.Actions += [PSCustomObject]@{
                        Action = $sessionState.LastAction
                        Time = $sessionState.LastActionTime
                        Result = $actionResult
                    }
                }
                "3" {
                    # Compile Test App
                    $actionResult = Compile-TestApp
                    $sessionState.LastAction = "Compile Test App"
                    $sessionState.LastActionTime = Get-Date
                    $sessionState.LastActionResult = $actionResult
                    $result.Actions += [PSCustomObject]@{
                        Action = $sessionState.LastAction
                        Time = $sessionState.LastActionTime
                        Result = $actionResult
                    }
                }
                "4" {
                    # Deploy Main App
                    $actionResult = Deploy-MainApp
                    $sessionState.LastAction = "Deploy Main App"
                    $sessionState.LastActionTime = Get-Date
                    $sessionState.LastActionResult = $actionResult
                    $result.Actions += [PSCustomObject]@{
                        Action = $sessionState.LastAction
                        Time = $sessionState.LastActionTime
                        Result = $actionResult
                    }
                }
                "5" {
                    # Deploy Test App
                    $actionResult = Deploy-TestApp
                    $sessionState.LastAction = "Deploy Test App"
                    $sessionState.LastActionTime = Get-Date
                    $sessionState.LastActionResult = $actionResult
                    $result.Actions += [PSCustomObject]@{
                        Action = $sessionState.LastAction
                        Time = $sessionState.LastActionTime
                        Result = $actionResult
                    }
                }
                "6" {
                    # Run All Tests
                    $actionResult = Run-AllTests
                    $sessionState.LastAction = "Run All Tests"
                    $sessionState.LastActionTime = Get-Date
                    $sessionState.LastActionResult = $actionResult
                    $result.Actions += [PSCustomObject]@{
                        Action = $sessionState.LastAction
                        Time = $sessionState.LastActionTime
                        Result = $actionResult
                    }
                }
                "7" {
                    # Run Specific Tests
                    $actionResult = Run-SpecificTests
                    $sessionState.LastAction = "Run Specific Tests"
                    $sessionState.LastActionTime = Get-Date
                    $sessionState.LastActionResult = $actionResult
                    $result.Actions += [PSCustomObject]@{
                        Action = $sessionState.LastAction
                        Time = $sessionState.LastActionTime
                        Result = $actionResult
                    }
                }
                "8" {
                    # View Test Results
                    $actionResult = View-TestResults
                    $sessionState.LastAction = "View Test Results"
                    $sessionState.LastActionTime = Get-Date
                    $sessionState.LastActionResult = $actionResult
                    $result.Actions += [PSCustomObject]@{
                        Action = $sessionState.LastAction
                        Time = $sessionState.LastActionTime
                        Result = $actionResult
                    }
                }
                "9" {
                    # Edit Configuration Settings
                    $actionResult = Edit-Configuration
                    $sessionState.LastAction = "Edit Configuration Settings"
                    $sessionState.LastActionTime = Get-Date
                    $sessionState.LastActionResult = $actionResult
                    $result.Actions += [PSCustomObject]@{
                        Action = $sessionState.LastAction
                        Time = $sessionState.LastActionTime
                        Result = $actionResult
                    }
                }
                default {
                    Write-WarningMessage "Invalid selection. Please enter a number between 0 and 9."
                    Start-Sleep -Seconds 2
                    continue
                }
            }

            # Wait for user to press a key before returning to the menu (for all actions)
            if ($selection -ne "0") {
                Write-Host ""
                Write-Host "Press any key to continue..." -ForegroundColor Yellow
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
    }
    catch {
        $result.Success = $false
        $result.Message = "An unexpected error occurred: $_"
        Write-ErrorMessage $result.Message
    }

    return $result
}

# Start the TDD session
$sessionResult = Start-TDDSession
return $sessionResult

#endregion