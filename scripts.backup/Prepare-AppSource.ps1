<#
.SYNOPSIS
    Prepares AL source code for compilation by copying to a build directory.
.DESCRIPTION
    This script prepares AL source code for compilation by:
    1. Taking parameters for source directory, output directory, and app type (main/test)
    2. Creating the output directory if it doesn't exist
    3. Creating a .gitignore file in the build directory root to exclude build artifacts from version control
    4. Copying the AL source files to the output directory, excluding any temporary or build files
    5. Validating the app.json file for required fields (publisher, name, version)
    6. Returning a strongly-typed [pscustomobject] with results

    This script uses common utility functions from Common-Functions.ps1 and configuration
    from TDDConfig.psd1 for consistent functionality across the TDD workflow scripts.
.PARAMETER ConfigPath
    Path to the configuration file. Default is "scripts\TDDConfig.psd1" in the same directory as this script.
.PARAMETER SourceDirectory
    Path to the source directory containing AL files. If not specified, uses the path from configuration based on AppType.
.PARAMETER OutputDirectory
    Path to the output directory where the source files will be copied. If not specified, uses the path from configuration based on AppType.
.PARAMETER AppType
    Type of app to prepare. Valid values are "Main" and "Test". Default is "Main".
.EXAMPLE
    .\scripts\Prepare-AppSource.ps1
    # Prepares the main app source using default paths from configuration
.EXAMPLE
    .\scripts\Prepare-AppSource.ps1 -AppType "Test"
    # Prepares the test app source using default paths from configuration
.EXAMPLE
    .\scripts\Prepare-AppSource.ps1 -SourceDirectory ".\app" -OutputDirectory ".\build\app" -AppType "Main"
    # Prepares the main app source using specified paths
.NOTES
    This script is part of the Business Central TDD workflow.

    Author: AI Assistant
    Date: 2023-11-15
    Version: 1.1

    Change Log:
    1.0 - Initial version
    1.1 - Added functionality to create .gitignore file in build directory root
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $false)]
    [string]$SourceDirectory,

    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Main", "Test")]
    [string]$AppType = "Main"
)

#region Script Initialization

# Fail fast on any terminating / non-terminating error
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'
$InformationPreference = 'Continue'
$WarningPreference = 'Continue'

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
$commonFunctionsPath = Join-Path -Path $scriptDir -ChildPath "Common-Functions.ps1"
if (-not (Test-Path -Path $commonFunctionsPath)) {
    Write-Error "Common-Functions.ps1 not found at path: $commonFunctionsPath. Make sure the script exists in the same folder as this script."
    exit 1
}
. $commonFunctionsPath

# Import Get-TDDConfiguration.ps1
$getTDDConfigPath = Join-Path -Path $scriptDir -ChildPath "Get-TDDConfiguration.ps1"
if (-not (Test-Path -Path $getTDDConfigPath)) {
    Write-Error "Get-TDDConfiguration.ps1 not found at path: $getTDDConfigPath. Make sure the script exists in the same folder as this script."
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

function New-GitIgnoreFile {
    <#
    .SYNOPSIS
        Creates a .gitignore file in the build directory.
    .DESCRIPTION
        Creates a .gitignore file in the build directory with patterns to exclude all files
        within the build directory from version control.
    .PARAMETER BuildDirectory
        Path to the build directory where the .gitignore file will be created.
    .OUTPUTS
        System.Boolean. Returns $true if the file was created successfully, $false otherwise.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BuildDirectory
    )

    try {
        # Determine the root build directory from the configuration
        $gitIgnorePath = Join-Path -Path $BuildDirectory -ChildPath ".gitignore"

        # Check if .gitignore already exists
        if (Test-Path -Path $gitIgnorePath -PathType Leaf) {
            Write-InfoMessage ".gitignore file already exists in $BuildDirectory"
            return $true
        }

        # Create .gitignore content
        $gitIgnoreContent = @"
# Ignore all files in the build directory
*
*/
!.gitignore

# This .gitignore file prevents compiled artifacts and temporary build files
# from being committed to the repository.
"@

        # Write the .gitignore file if ShouldProcess is confirmed
        if ($PSCmdlet.ShouldProcess($gitIgnorePath, "Create .gitignore file")) {
            Set-Content -Path $gitIgnorePath -Value $gitIgnoreContent -Force
            Write-InfoMessage "Created .gitignore file in $BuildDirectory"
            return $true
        }
        else {
            Write-InfoMessage "Skipped creating .gitignore file in $BuildDirectory (ShouldProcess declined)"
            return $false
        }
    }
    catch {
        Write-ErrorMessage "Failed to create .gitignore file: $_"
        return $false
    }
}

function Test-AppJsonFile {
    <#
    .SYNOPSIS
        Validates the app.json file for required fields.
    .DESCRIPTION
        Checks if the app.json file exists and contains the required fields (publisher, name, version).
    .PARAMETER AppJsonPath
        Path to the app.json file.
    .OUTPUTS
        PSCustomObject. Returns an object with validation results.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppJsonPath
    )

    $result = [PSCustomObject]@{
        Valid = $false
        Message = ""
        AppJson = $null
    }

    try {
        # Check if app.json exists
        if (-not (Test-Path -Path $AppJsonPath -PathType Leaf)) {
            $result.Message = "app.json file not found at path: $AppJsonPath"
            return $result
        }

        # Read and parse app.json
        $appJsonContent = Get-Content -Path $AppJsonPath -Raw | ConvertFrom-Json

        # Check required fields
        $missingFields = @()

        if (-not $appJsonContent.publisher) {
            $missingFields += "publisher"
        }

        if (-not $appJsonContent.name) {
            $missingFields += "name"
        }

        if (-not $appJsonContent.version) {
            $missingFields += "version"
        }

        if ($missingFields.Count -gt 0) {
            $result.Message = "app.json is missing required fields: $($missingFields -join ', ')"
            return $result
        }

        # Validation passed
        $result.Valid = $true
        $result.Message = "app.json validation passed"
        $result.AppJson = $appJsonContent

        return $result
    }
    catch {
        $result.Message = "Error validating app.json: $_"
        return $result
    }
}

function Copy-AppSource {
    <#
    .SYNOPSIS
        Copies AL source files to the output directory.
    .DESCRIPTION
        Copies AL source files to the output directory, excluding any temporary or build files.
    .PARAMETER SourceDirectory
        Path to the source directory containing AL files.
    .PARAMETER OutputDirectory
        Path to the output directory where the source files will be copied.
    .OUTPUTS
        PSCustomObject. Returns an object with copy results.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDirectory,

        [Parameter(Mandatory = $true)]
        [string]$OutputDirectory
    )

    $result = [PSCustomObject]@{
        Success = $false
        Message = ""
        FilesCopied = 0
        FilesSkipped = 0
    }

    try {
        # Check if source directory exists
        if (-not (Test-Path -Path $SourceDirectory -PathType Container)) {
            $result.Message = "Source directory not found: $SourceDirectory"
            return $result
        }

        # Create output directory if it doesn't exist
        if (-not (Test-Path -Path $OutputDirectory -PathType Container)) {
            New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
            Write-InfoMessage "Created output directory: $OutputDirectory"
        }

        # Define files/directories to exclude
        $excludePatterns = @(
            "*.app",
            "*.vsix",
            "*.zip",
            "*.bak",
            "*.tmp",
            "*.temp",
            "*.log",
            "*.orig",
            ".vs",
            ".vscode",
            ".git",
            ".alpackages",
            "node_modules",
            "bin",
            "obj",
            "output",
            "testresults"
        )

        # Get all files from source directory
        $sourceFiles = Get-ChildItem -Path $SourceDirectory -Recurse -File

        # Initialize counters
        $filesCopied = 0
        $filesSkipped = 0

        # Copy files
        foreach ($file in $sourceFiles) {
            # Check if file should be excluded
            $shouldExclude = $false
            foreach ($pattern in $excludePatterns) {
                if ($file.FullName -like "*$pattern*") {
                    $shouldExclude = $true
                    break
                }
            }

            if ($shouldExclude) {
                $filesSkipped++
                continue
            }

            # Get relative path
            $relativePath = $file.FullName.Substring($SourceDirectory.Length)
            if ($relativePath.StartsWith("\") -or $relativePath.StartsWith("/")) {
                $relativePath = $relativePath.Substring(1)
            }

            # Create target path
            $targetPath = Join-Path -Path $OutputDirectory -ChildPath $relativePath

            # Create directory if it doesn't exist
            $targetDir = Split-Path -Parent $targetPath
            if (-not (Test-Path -Path $targetDir -PathType Container)) {
                New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
            }

            # Copy file
            Copy-Item -Path $file.FullName -Destination $targetPath -Force
            $filesCopied++
        }

        # Set result
        $result.Success = $true
        $result.Message = "Successfully copied $filesCopied files to $OutputDirectory (skipped $filesSkipped files)"
        $result.FilesCopied = $filesCopied
        $result.FilesSkipped = $filesSkipped

        return $result
    }
    catch {
        $result.Message = "Error copying files: $_"
        return $result
    }
}

function Invoke-PrepareAppSource {
    <#
    .SYNOPSIS
        Main function to prepare AL source code for compilation.
    .DESCRIPTION
        Prepares AL source code for compilation by copying to a build directory and validating app.json.
    .PARAMETER Config
        The configuration object.
    .PARAMETER SourceDirectory
        Path to the source directory containing AL files.
    .PARAMETER OutputDirectory
        Path to the output directory where the source files will be copied.
    .PARAMETER AppType
        Type of app to prepare. Valid values are "Main" and "Test".
    .OUTPUTS
        PSCustomObject. Returns an object with the results of the operation.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $false)]
        [string]$SourceDirectory,

        [Parameter(Mandatory = $false)]
        [string]$OutputDirectory,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Main", "Test")]
        [string]$AppType = "Main"
    )

    # Initialize result object
    $result = [PSCustomObject]@{
        Success = $false
        Message = ""
        AppType = $AppType
        SourceDirectory = $null
        OutputDirectory = $null
        AppJson = $null
        FilesCopied = 0
        FilesSkipped = 0
        Timestamp = Get-Date
    }

    try {
        # Determine source and output directories based on app type
        if ([string]::IsNullOrWhiteSpace($SourceDirectory)) {
            if ($AppType -eq "Main") {
                $SourceDirectory = $Config.SourcePaths.App
            } else {
                $SourceDirectory = $Config.SourcePaths.Test
            }
        }

        if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
            if ($AppType -eq "Main") {
                $OutputDirectory = $Config.OutputPaths.AppSource
            } else {
                $OutputDirectory = $Config.OutputPaths.TestSource
            }
        }

        # Resolve paths
        $resolvedSourceDir = Resolve-TDDPath -Path $SourceDirectory
        $resolvedOutputDir = Resolve-TDDPath -Path $OutputDirectory -CreateIfNotExists

        # Check if we need to create a .gitignore file in the build directory
        $buildDirPath = $Config.OutputPaths.Build
        $resolvedBuildDir = Resolve-TDDPath -Path $buildDirPath -CreateIfNotExists

        # Create .gitignore file in the build directory root
        New-GitIgnoreFile -BuildDirectory $resolvedBuildDir

        # Update result with resolved paths
        $result.SourceDirectory = $resolvedSourceDir
        $result.OutputDirectory = $resolvedOutputDir

        # Display section header
        Write-SectionHeader "Preparing $AppType App Source" -ForegroundColor Cyan -DecorationType Underline

        # Display information about the operation
        Write-InfoMessage "Starting source preparation with the following parameters:"
        Write-InfoMessage "  App Type: $AppType"
        Write-InfoMessage "  Source Directory: $resolvedSourceDir"
        Write-InfoMessage "  Output Directory: $resolvedOutputDir"

        # Check if source directory exists
        if (-not (Test-Path -Path $resolvedSourceDir -PathType Container)) {
            throw "Source directory not found: $resolvedSourceDir"
        }

        # Copy source files
        Write-InfoMessage "Copying source files..."
        $copyResult = Copy-AppSource -SourceDirectory $resolvedSourceDir -OutputDirectory $resolvedOutputDir

        if (-not $copyResult.Success) {
            throw "Failed to copy source files: $($copyResult.Message)"
        }

        Write-InfoMessage $copyResult.Message

        # Update result with copy information
        $result.FilesCopied = $copyResult.FilesCopied
        $result.FilesSkipped = $copyResult.FilesSkipped

        # Validate app.json
        $appJsonPath = Join-Path -Path $resolvedOutputDir -ChildPath "app.json"
        Write-InfoMessage "Validating app.json..."
        $appJsonResult = Test-AppJsonFile -AppJsonPath $appJsonPath

        if (-not $appJsonResult.Valid) {
            throw "app.json validation failed: $($appJsonResult.Message)"
        }

        Write-InfoMessage "app.json validation passed"

        # Update result with app.json information
        $result.AppJson = $appJsonResult.AppJson

        # Operation succeeded
        $result.Success = $true
        $result.Message = "Successfully prepared $AppType app source"

        Write-SuccessMessage $result.Message
    }
    catch {
        # Handle any unexpected errors
        $result.Success = $false
        $result.Message = "An error occurred while preparing app source: $_"

        Write-ErrorMessage $result.Message
    }

    return $result
}

#endregion

#region Main Script Execution

# Display script header
Write-SectionHeader "Prepare App Source" -ForegroundColor Cyan -DecorationType Box

# Execute the main function
$result = Invoke-PrepareAppSource -Config $config -SourceDirectory $SourceDirectory -OutputDirectory $OutputDirectory -AppType $AppType

# Return the result
return $result

#endregion