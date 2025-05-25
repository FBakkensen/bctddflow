@{
    # Environment Settings
    ContainerName = "bctest"
    ArtifactUrl = ""  # Empty string means latest sandbox artifact will be used
    Auth = "NavUserPassword"  # Options: "Windows", "UserPassword", "NavUserPassword"
    Country = "w1"  # Default country for Business Central
    MemoryLimit = "8G"  # Memory limit for the container
    Accept_Eula = $true
    Accept_Outdated = $true
    IncludeTestFrameworkOnly = $true
    IncludeTestToolkit = $true
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
        SuppressBcContainerHelperVerbose = $true  # Suppress verbose output from BcContainerHelper module
    }
}
