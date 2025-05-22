<#
.SYNOPSIS
    Loads and validates the TDD configuration for Business Central.
.DESCRIPTION
    This script provides a function to load the TDDConfig.psd1 file, validate required settings,
    allow overriding settings via parameters, merge default settings with user-provided settings,
    and return a complete configuration object for use in other scripts.
.PARAMETER ConfigPath
    Path to the configuration file. Default is "scripts\TDDConfig.psd1" in the same directory as this script.
.PARAMETER OverrideSettings
    A hashtable of settings to override from the configuration file.
.PARAMETER RequiredSettings
    An array of setting keys that must be present in the final configuration.
.PARAMETER ValidateOnly
    If specified, only validates the configuration without returning it.
.EXAMPLE
    $config = .\scripts\Get-TDDConfiguration.ps1
    # Loads the default configuration file and returns the configuration object
.EXAMPLE
    $config = .\scripts\Get-TDDConfiguration.ps1 -ConfigPath "C:\MyProject\CustomConfig.psd1"
    # Loads a custom configuration file and returns the configuration object
.EXAMPLE
    $config = .\scripts\Get-TDDConfiguration.ps1 -OverrideSettings @{ ContainerName = "mycontainer"; Auth = "Windows" }
    # Loads the default configuration file, overrides specific settings, and returns the configuration object
.EXAMPLE
    $config = .\scripts\Get-TDDConfiguration.ps1 -RequiredSettings @("ContainerName", "Auth", "MemoryLimit")
    # Loads the default configuration file, validates that required settings are present, and returns the configuration object
.EXAMPLE
    $isValid = .\scripts\Get-TDDConfiguration.ps1 -ValidateOnly
    # Validates the configuration without returning it, returns $true if valid, $false otherwise
.NOTES
    This script is part of the Business Central TDD workflow.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $false)]
    [hashtable]$OverrideSettings,

    [Parameter(Mandatory = $false)]
    [string[]]$RequiredSettings,

    [Parameter(Mandatory = $false)]
    [switch]$ValidateOnly
)

# Fail fast on any terminating / non-terminating error
$ErrorActionPreference = 'Stop'
$VerbosePreference     = 'Continue'
$InformationPreference = 'Continue'
$WarningPreference     = 'Continue'

# Set default config path if not provided
if (-not $PSBoundParameters.ContainsKey('ConfigPath') -or [string]::IsNullOrWhiteSpace($ConfigPath)) {
    $scriptPath = $MyInvocation.MyCommand.Path
    $scriptDir = Split-Path -Parent $scriptPath
    $ConfigPath = Join-Path -Path $scriptDir -ChildPath "TDDConfig.psd1"
    Write-Host "INFO: Using default configuration path: $ConfigPath" -ForegroundColor Cyan
}

# We'll use direct Write-Host calls instead of custom functions to avoid scope issues

function Get-TDDConfiguration {
    <#
    .SYNOPSIS
        Gets the TDD configuration for Business Central.
    .DESCRIPTION
        Loads the TDDConfig.psd1 file, validates required settings, allows overriding settings,
        merges default settings with user-provided settings, and returns a complete configuration object.
    .PARAMETER ConfigPath
        Path to the configuration file.
    .PARAMETER OverrideSettings
        A hashtable of settings to override from the configuration file.
    .PARAMETER RequiredSettings
        An array of setting keys that must be present in the final configuration.
    .PARAMETER ValidateOnly
        If specified, only validates the configuration without returning it.
    .OUTPUTS
        System.Collections.Hashtable. Returns the configuration hashtable if ValidateOnly is not specified.
        System.Boolean. Returns $true if ValidateOnly is specified and the configuration is valid, $false otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [hashtable]$OverrideSettings,

        [Parameter(Mandatory = $false)]
        [string[]]$RequiredSettings,

        [Parameter(Mandatory = $false)]
        [switch]$ValidateOnly
    )

    # Default configuration values
    $defaultConfig = @{
        # Environment Settings
        ContainerName = "bctest"
        ArtifactUrl = ""  # Empty string means latest sandbox artifact will be used
        Auth = "NavUserPassword"  # Options: "Windows", "UserPassword", "NavUserPassword"
        Country = "w1"  # Default country for Business Central
        MemoryLimit = "8G"  # Memory limit for the container
        Accept_Eula = $true
        Accept_Outdated = $true
        IncludeTestToolkit = $true
        IncludePerformanceToolkit = $true
        AssignPremiumPlan = $true
        DNS = "8.8.8.8"
        UpdateHosts = $true
        
        # Path Settings
        SourcePaths = @{
            App = ".\app"  # Main app source path
            Test = ".\test"  # Test app source path
        }
        
        OutputPaths = @{
            Build = ".\build"  # Base build directory
            AppSource = ".\build\app"  # Prepared app source
            TestSource = ".\build\test"  # Prepared test source
            AppOutput = ".\build\output"  # Compiled app output directory
            TestResults = ".\build\testresults"  # Test results directory
        }
        
        # Compilation Settings
        Compilation = @{
            CodeAnalysis = $true  # Enable code analysis during compilation
            GenerateReportLayout = $true  # Generate report layouts
            TreatWarningsAsErrors = $false  # Treat compiler warnings as errors
            EnableCodeCop = $true  # Enable CodeCop rules
            EnableAppSourceCop = $true  # Enable AppSource rules
            EnablePerTenantExtensionCop = $true  # Enable PTEs rules
            EnableUICop = $true  # Enable UI rules
            FailOnTestCodeIssues = $true  # Fail if test code has issues
        }
        
        # Publishing Settings
        Publishing = @{
            Scope = "tenant"  # Options: "tenant", "global"
            SyncMode = "ForceSync"  # Options: "Add", "Clean", "ForceSync", "Development"
            SkipVerification = $false  # Skip verification during publishing
            PublishingTimeout = 1800  # Timeout for publishing operations (seconds)
            InstallDependencies = $true  # Automatically install dependencies
            InstallOnlyReferencedApps = $true  # Install only referenced apps
        }
        
        # Test Settings
        TestSettings = @{
            DefaultTimeout = 600  # Default timeout for test execution (seconds)
            FailFast = $false  # Stop on first test failure
            ExtensionId = ""  # Specific extension ID to test (empty for all)
            TestCodeunit = ""  # Specific test codeunit to run (empty for all)
            TestFunction = ""  # Specific test function to run (empty for all)
            TestRunnerCodeunitId = 130451  # Default test runner codeunit ID
            DisableNameValidation = $false  # Disable test name validation
            RetryCount = 0  # Number of retries for failed tests
        }
        
        # Watch Mode Settings
        WatchSettings = @{
            Enabled = $true  # Enable watch mode
            Interval = 2  # Check interval in seconds
            AutoPublish = $true  # Auto-publish on changes
            AutoRunTests = $true  # Auto-run tests after publishing
            IncludeSubfolders = $true  # Watch subfolders
        }
        
        # TDD Session Settings
        TDDSession = @{
            RememberLastRun = $true  # Remember last test run
            AutoSaveResults = $true  # Auto-save test results
            DefaultResultsFormat = "XML"  # Default results format (XML, JSON)
            ShowPassedTests = $true  # Show passed tests in results
            DetailLevel = "Detailed"  # Result detail level (Basic, Detailed, Verbose)
        }
        
        # Script Behavior Settings
        ScriptSettings = @{
            VerboseOutput = $true  # Enable verbose output
            ErrorActionPreference = "Stop"  # Default error action
            WarningActionPreference = "Continue"  # Default warning action
            InformationPreference = "Continue"  # Default information action
            ProgressPreference = "SilentlyContinue"  # Default progress preference
        }
    }

    # Initialize the configuration with default values
    $config = $defaultConfig.Clone()

    # Try to import configuration from file
    try {
        if (-not [string]::IsNullOrWhiteSpace($ConfigPath) -and (Test-Path -Path $ConfigPath)) {
            Write-Host "INFO: Loading configuration from $ConfigPath..." -ForegroundColor Cyan
            $importedConfig = Import-PowerShellDataFile -Path $ConfigPath -ErrorAction Stop

            # Merge with default configuration (imported config takes precedence)
            # This is a deep merge that handles nested hashtables
            $config = Merge-Hashtables -BaseTable $config -OverrideTable $importedConfig

            Write-Host "INFO: Configuration loaded successfully." -ForegroundColor Cyan
        } else {
            Write-Host "WARNING: Configuration file not found at $ConfigPath. Using default values." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "WARNING: Error loading configuration from $ConfigPath`: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "WARNING: Using default configuration values." -ForegroundColor Yellow
    }

    # Apply override settings if provided
    if ($OverrideSettings -and $OverrideSettings.Count -gt 0) {
        Write-Host "INFO: Applying override settings..." -ForegroundColor Cyan
        $config = Merge-Hashtables -BaseTable $config -OverrideTable $OverrideSettings
        Write-Host "INFO: Override settings applied successfully." -ForegroundColor Cyan
    }

    # Validate required settings if specified
    $validationPassed = $true
    if ($RequiredSettings -and $RequiredSettings.Count -gt 0) {
        Write-Host "INFO: Validating required settings..." -ForegroundColor Cyan
        $missingSettings = @()

        foreach ($key in $RequiredSettings) {
            # Handle nested keys with dot notation (e.g., "Publishing.Scope")
            if ($key -like "*.*") {
                $keyParts = $key -split "\."
                $currentValue = $config
                $keyExists = $true

                foreach ($part in $keyParts) {
                    if ($currentValue -is [hashtable] -and $currentValue.ContainsKey($part)) {
                        $currentValue = $currentValue[$part]
                    } else {
                        $keyExists = $false
                        break
                    }
                }

                if (-not $keyExists) {
                    $missingSettings += $key
                }
            } else {
                # Handle top-level keys
                if (-not $config.ContainsKey($key)) {
                    $missingSettings += $key
                }
            }
        }

        if ($missingSettings.Count -gt 0) {
            $validationPassed = $false
            Write-Host "ERROR: Missing required settings: $($missingSettings -join ', ')" -ForegroundColor Red
        } else {
            Write-Host "SUCCESS: All required settings are present." -ForegroundColor Green
        }
    }

    # Return validation result if ValidateOnly is specified
    if ($ValidateOnly) {
        return $validationPassed
    }

    # Return the configuration if validation passed
    if ($validationPassed) {
        return $config
    } else {
        Write-Host "ERROR: Configuration validation failed. Please check the configuration file and required settings." -ForegroundColor Red
        return $null
    }
}

function Merge-Hashtables {
    <#
    .SYNOPSIS
        Merges two hashtables with deep merging of nested hashtables.
    .DESCRIPTION
        Merges the override hashtable into the base hashtable, with values from the override hashtable taking precedence.
        Nested hashtables are merged recursively rather than being replaced.
    .PARAMETER BaseTable
        The base hashtable to merge into.
    .PARAMETER OverrideTable
        The hashtable with values to override in the base hashtable.
    .OUTPUTS
        System.Collections.Hashtable. Returns the merged hashtable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$BaseTable,

        [Parameter(Mandatory = $true)]
        [hashtable]$OverrideTable
    )

    # Create a new hashtable to avoid modifying the original
    $result = $BaseTable.Clone()

    # Merge the override table into the result
    foreach ($key in $OverrideTable.Keys) {
        if ($result.ContainsKey($key)) {
            # If both values are hashtables, merge them recursively
            if ($result[$key] -is [hashtable] -and $OverrideTable[$key] -is [hashtable]) {
                $result[$key] = Merge-Hashtables -BaseTable $result[$key] -OverrideTable $OverrideTable[$key]
            } else {
                # Otherwise, override the value
                $result[$key] = $OverrideTable[$key]
            }
        } else {
            # Add the new key-value pair
            $result[$key] = $OverrideTable[$key]
        }
    }

    return $result
}

# Execute the function with the provided parameters
$params = @{}
if ($PSBoundParameters.ContainsKey('ConfigPath')) { $params['ConfigPath'] = $ConfigPath }
if ($PSBoundParameters.ContainsKey('OverrideSettings')) { $params['OverrideSettings'] = $OverrideSettings }
if ($PSBoundParameters.ContainsKey('RequiredSettings')) { $params['RequiredSettings'] = $RequiredSettings }
if ($PSBoundParameters.ContainsKey('ValidateOnly')) { $params['ValidateOnly'] = $ValidateOnly }

$result = Get-TDDConfiguration @params

# Return the result
return $result