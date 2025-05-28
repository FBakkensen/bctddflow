<#
.SYNOPSIS
    Prepares AL source code for compilation or AppSource submission.
.DESCRIPTION
    This script supports two modes of operation:

    BUILD MODE (default):
    1. Taking parameters for source directory, output directory, and app type (main/test)
    2. Creating the output directory if it doesn't exist
    3. Creating a .gitignore file in the build directory root to exclude build artifacts from version control
    4. Copying the AL source files to the output directory, excluding any temporary or build files
    5. Validating the app.json file for required fields (publisher, name, version)
    6. Returning a strongly-typed [pscustomobject] with results

    APPSOURCE MODE (-PrepareForAppSource switch):
    1. Deletes all source files from the target app directory (preserves app.json, AppSourceCop.json, Translations)
    2. Copies replacement source files from the specified ReplacementSourcePath to the target app directory
    3. Validates the app.json file for required fields
    4. Maintains directory structure and file organization

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
.PARAMETER PrepareForAppSource
    Switch parameter to enable AppSource preparation mode. When specified, the script will delete existing source files from the target app and replace them with files from ReplacementSourcePath.
.PARAMETER ReplacementSourcePath
    Path to the directory containing replacement source files. Required when PrepareForAppSource is specified. The directory structure should match the target app structure.
.EXAMPLE
    .\scripts\Prepare-AppSource.ps1
    # Prepares the main app source using default paths from configuration (BUILD MODE)
.EXAMPLE
    .\scripts\Prepare-AppSource.ps1 -AppType "Test"
    # Prepares the test app source using default paths from configuration (BUILD MODE)
.EXAMPLE
    .\scripts\Prepare-AppSource.ps1 -SourceDirectory ".\app" -OutputDirectory ".\build\app" -AppType "Main"
    # Prepares the main app source using specified paths (BUILD MODE)
.EXAMPLE
    .\scripts\Prepare-AppSource.ps1 -PrepareForAppSource -ReplacementSourcePath ".\appsource-ready\app" -AppType "Main"
    # Prepares the main app for AppSource submission by replacing source files (APPSOURCE MODE)
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
    [string]$AppType = "Main",

    [Parameter(Mandatory = $false)]
    [switch]$PrepareForAppSource,

    [Parameter(Mandatory = $false)]
    [string]$ReplacementSourcePath
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

function Remove-AppSourceFiles {
    <#
    .SYNOPSIS
        Removes existing source files from the target app directory for AppSource preparation.
    .DESCRIPTION
        Safely deletes AL source files from the target app directory while preserving
        configuration files like app.json, AppSourceCop.json, and Translations directory.
    .PARAMETER TargetDirectory
        Path to the target app directory where source files will be removed.
    .OUTPUTS
        PSCustomObject. Returns an object with removal results.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetDirectory
    )

    $result = [PSCustomObject]@{
        Success = $false
        Message = ""
        FilesRemoved = 0
        DirectoriesRemoved = 0
        PreservedFiles = @()
    }

    try {
        # Check if target directory exists
        if (-not (Test-Path -Path $TargetDirectory -PathType Container)) {
            $result.Message = "Target directory not found: $TargetDirectory"
            return $result
        }

        # Define files and directories to preserve
        $preserveItems = @(
            "app.json",
            "AppSourceCop.json",
            "Translations",
            "logo.png",
            ".gitignore"
        )

        # Define source file patterns to remove
        $sourceFilePatterns = @(
            "*.al",
            "*.permissionset.al",
            "*.profile.al"
        )

        # Define directories to remove completely
        $sourceDirectories = @(
            "src"
        )

        $filesRemoved = 0
        $directoriesRemoved = 0
        $preservedFiles = @()

        # Remove source files in root directory
        foreach ($pattern in $sourceFilePatterns) {
            $filesToRemove = Get-ChildItem -Path $TargetDirectory -Filter $pattern -File
            foreach ($file in $filesToRemove) {
                if ($preserveItems -notcontains $file.Name) {
                    if ($PSCmdlet.ShouldProcess($file.FullName, "Remove source file")) {
                        Remove-Item -Path $file.FullName -Force
                        $filesRemoved++
                        Write-InfoMessage "Removed source file: $($file.Name)"
                    }
                } else {
                    $preservedFiles += $file.Name
                    Write-InfoMessage "Preserved file: $($file.Name)"
                }
            }
        }

        # Remove source directories
        foreach ($dirName in $sourceDirectories) {
            $dirPath = Join-Path -Path $TargetDirectory -ChildPath $dirName
            if (Test-Path -Path $dirPath -PathType Container) {
                if ($PSCmdlet.ShouldProcess($dirPath, "Remove source directory")) {
                    Remove-Item -Path $dirPath -Recurse -Force
                    $directoriesRemoved++
                    Write-InfoMessage "Removed source directory: $dirName"
                }
            }
        }

        # Update result
        $result.Success = $true
        $result.Message = "Successfully removed $filesRemoved source files and $directoriesRemoved directories from $TargetDirectory"
        $result.FilesRemoved = $filesRemoved
        $result.DirectoriesRemoved = $directoriesRemoved
        $result.PreservedFiles = $preservedFiles

        return $result
    }
    catch {
        $result.Message = "Error removing source files: $_"
        return $result
    }
}

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

        # Define file extensions to exclude
        $excludeFilePatterns = @(
            "*.app",
            "*.vsix",
            "*.zip",
            "*.bak",
            "*.tmp",
            "*.temp",
            "*.log",
            "*.orig"
        )

        # Define directory names to exclude (exact matches)
        $excludeDirectoryNames = @(
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

            # Check file extension patterns
            foreach ($pattern in $excludeFilePatterns) {
                if ($file.Name -like $pattern) {
                    $shouldExclude = $true
                    break
                }
            }

            # Check if file is in an excluded directory
            if (-not $shouldExclude) {
                $relativePath = $file.FullName.Substring($SourceDirectory.Length)
                if ($relativePath.StartsWith("\") -or $relativePath.StartsWith("/")) {
                    $relativePath = $relativePath.Substring(1)
                }

                $pathParts = $relativePath.Split([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
                foreach ($dirName in $excludeDirectoryNames) {
                    if ($pathParts -contains $dirName) {
                        $shouldExclude = $true
                        break
                    }
                }
            }

            if ($shouldExclude) {
                $filesSkipped++
                continue
            }

            # Get relative path (reuse the one calculated above if available)
            if (-not $relativePath) {
                $relativePath = $file.FullName.Substring($SourceDirectory.Length)
                if ($relativePath.StartsWith("\") -or $relativePath.StartsWith("/")) {
                    $relativePath = $relativePath.Substring(1)
                }
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

function Copy-LogoFile {
    <#
    .SYNOPSIS
        Copies logo file referenced in app.json to the build directory.
    .DESCRIPTION
        Parses the app.json file to find logo references and copies the logo file
        to the build directory maintaining the correct relative path structure.
    .PARAMETER AppJsonPath
        Path to the app.json file in the build directory.
    .PARAMETER SourceDirectory
        Path to the source directory (app directory).
    .PARAMETER OutputDirectory
        Path to the output directory (build directory).
    .OUTPUTS
        PSCustomObject. Returns an object with copy results.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppJsonPath,

        [Parameter(Mandatory = $true)]
        [string]$SourceDirectory,

        [Parameter(Mandatory = $true)]
        [string]$OutputDirectory
    )

    $result = [PSCustomObject]@{
        Success = $false
        Message = ""
        LogoCopied = $false
        LogoPath = ""
    }

    try {
        # Check if app.json exists
        if (-not (Test-Path -Path $AppJsonPath -PathType Leaf)) {
            $result.Message = "app.json not found: $AppJsonPath"
            return $result
        }

        # Read and parse app.json
        $appJsonContent = Get-Content -Path $AppJsonPath -Raw | ConvertFrom-Json

        # Check if logo property exists
        if (-not $appJsonContent.PSObject.Properties['logo']) {
            $result.Success = $true
            $result.Message = "No logo reference found in app.json"
            return $result
        }

        $logoPath = $appJsonContent.logo
        if ([string]::IsNullOrWhiteSpace($logoPath)) {
            $result.Success = $true
            $result.Message = "Logo property is empty in app.json"
            return $result
        }

        # Resolve logo source path relative to the source directory
        $logoSourcePath = Join-Path -Path $SourceDirectory -ChildPath $logoPath
        $logoSourcePath = [System.IO.Path]::GetFullPath($logoSourcePath)

        # Check if logo file exists
        if (-not (Test-Path -Path $logoSourcePath -PathType Leaf)) {
            $result.Message = "Logo file not found: $logoSourcePath (referenced as '$logoPath' in app.json)"
            return $result
        }

        # Resolve logo destination path relative to the output directory
        $logoDestPath = Join-Path -Path $OutputDirectory -ChildPath $logoPath
        $logoDestPath = [System.IO.Path]::GetFullPath($logoDestPath)

        # Create destination directory if it doesn't exist
        $logoDestDir = Split-Path -Parent $logoDestPath
        if (-not (Test-Path -Path $logoDestDir -PathType Container)) {
            New-Item -Path $logoDestDir -ItemType Directory -Force | Out-Null
            Write-InfoMessage "Created logo directory: $logoDestDir"
        }

        # Copy logo file
        Copy-Item -Path $logoSourcePath -Destination $logoDestPath -Force
        Write-InfoMessage "Copied logo file: $logoPath"

        # Set result
        $result.Success = $true
        $result.Message = "Successfully copied logo file: $logoPath"
        $result.LogoCopied = $true
        $result.LogoPath = $logoPath

        return $result
    }
    catch {
        $result.Message = "Error copying logo file: $_"
        return $result
    }
}

function Copy-ReplacementFiles {
    <#
    .SYNOPSIS
        Copies replacement source files to the target app directory for AppSource preparation.
    .DESCRIPTION
        Copies AL source files from the replacement source directory to the target app directory,
        maintaining the directory structure and file organization.
    .PARAMETER ReplacementSourcePath
        Path to the directory containing replacement source files.
    .PARAMETER TargetDirectory
        Path to the target app directory where replacement files will be copied.
    .OUTPUTS
        PSCustomObject. Returns an object with copy results.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReplacementSourcePath,

        [Parameter(Mandatory = $true)]
        [string]$TargetDirectory
    )

    $result = [PSCustomObject]@{
        Success = $false
        Message = ""
        FilesCopied = 0
        DirectoriesCopied = 0
    }

    try {
        # Check if replacement source directory exists
        if (-not (Test-Path -Path $ReplacementSourcePath -PathType Container)) {
            $result.Message = "Replacement source directory not found: $ReplacementSourcePath"
            return $result
        }

        # Check if target directory exists
        if (-not (Test-Path -Path $TargetDirectory -PathType Container)) {
            $result.Message = "Target directory not found: $TargetDirectory"
            return $result
        }

        # Define file extensions to copy (AL source files)
        $includeFilePatterns = @(
            "*.al",
            "*.permissionset.al",
            "*.profile.al"
        )

        # Define directories to copy completely
        $includeDirectories = @(
            "src"
        )

        $filesCopied = 0
        $directoriesCopied = 0

        # Copy source files from root directory
        foreach ($pattern in $includeFilePatterns) {
            $filesToCopy = Get-ChildItem -Path $ReplacementSourcePath -Filter $pattern -File
            foreach ($file in $filesToCopy) {
                $targetPath = Join-Path -Path $TargetDirectory -ChildPath $file.Name
                Copy-Item -Path $file.FullName -Destination $targetPath -Force
                $filesCopied++
                Write-InfoMessage "Copied source file: $($file.Name)"
            }
        }

        # Copy source directories
        foreach ($dirName in $includeDirectories) {
            $sourceDirPath = Join-Path -Path $ReplacementSourcePath -ChildPath $dirName
            if (Test-Path -Path $sourceDirPath -PathType Container) {
                $targetDirPath = Join-Path -Path $TargetDirectory -ChildPath $dirName

                # Remove target directory if it exists (it should have been removed by Remove-AppSourceFiles)
                if (Test-Path -Path $targetDirPath -PathType Container) {
                    Remove-Item -Path $targetDirPath -Recurse -Force
                }

                # Copy the entire directory structure
                Copy-Item -Path $sourceDirPath -Destination $targetDirPath -Recurse -Force
                $directoriesCopied++
                Write-InfoMessage "Copied source directory: $dirName"

                # Count files in the copied directory
                $copiedFiles = Get-ChildItem -Path $targetDirPath -Recurse -File
                $filesCopied += $copiedFiles.Count
            }
        }

        # Update result
        $result.Success = $true
        $result.Message = "Successfully copied $filesCopied files and $directoriesCopied directories from $ReplacementSourcePath to $TargetDirectory"
        $result.FilesCopied = $filesCopied
        $result.DirectoriesCopied = $directoriesCopied

        return $result
    }
    catch {
        $result.Message = "Error copying replacement files: $_"
        return $result
    }
}

function Invoke-PrepareAppSource {
    <#
    .SYNOPSIS
        Main function to prepare AL source code for compilation or AppSource submission.
    .DESCRIPTION
        Prepares AL source code for compilation by copying to a build directory and validating app.json,
        or prepares for AppSource submission by replacing source files with clean versions.
    .PARAMETER Config
        The configuration object.
    .PARAMETER SourceDirectory
        Path to the source directory containing AL files.
    .PARAMETER OutputDirectory
        Path to the output directory where the source files will be copied.
    .PARAMETER AppType
        Type of app to prepare. Valid values are "Main" and "Test".
    .PARAMETER PrepareForAppSource
        Switch parameter to enable AppSource preparation mode.
    .PARAMETER ReplacementSourcePath
        Path to the directory containing replacement source files for AppSource preparation.
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
        [string]$AppType = "Main",

        [Parameter(Mandatory = $false)]
        [switch]$PrepareForAppSource,

        [Parameter(Mandatory = $false)]
        [string]$ReplacementSourcePath
    )

    # Initialize result object
    $result = [PSCustomObject]@{
        Success = $false
        Message = ""
        AppType = $AppType
        Mode = if ($PrepareForAppSource) { "AppSource" } else { "Build" }
        SourceDirectory = $null
        OutputDirectory = $null
        ReplacementSourcePath = $ReplacementSourcePath
        AppJson = $null
        FilesCopied = 0
        FilesSkipped = 0
        FilesRemoved = 0
        DirectoriesRemoved = 0
        LogoCopied = $false
        LogoPath = ""
        Timestamp = Get-Date
    }

    try {
        # Validate parameters for AppSource mode
        if ($PrepareForAppSource) {
            if ([string]::IsNullOrWhiteSpace($ReplacementSourcePath)) {
                throw "ReplacementSourcePath is required when PrepareForAppSource is specified"
            }

            if (-not (Test-Path -Path $ReplacementSourcePath -PathType Container)) {
                throw "Replacement source directory not found: $ReplacementSourcePath"
            }
        }

        # Determine source and output directories based on app type and mode
        if ($PrepareForAppSource) {
            # For AppSource mode, we work directly with the app directory
            if ([string]::IsNullOrWhiteSpace($SourceDirectory)) {
                if ($AppType -eq "Main") {
                    $SourceDirectory = $Config.SourcePaths.App
                } else {
                    $SourceDirectory = $Config.SourcePaths.Test
                }
            }
            # In AppSource mode, source and output are the same (we modify in place)
            $OutputDirectory = $SourceDirectory
        } else {
            # For Build mode, use the existing logic
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
        }

        # Resolve paths
        $resolvedSourceDir = Resolve-TDDPath -Path $SourceDirectory
        $resolvedOutputDir = Resolve-TDDPath -Path $OutputDirectory -CreateIfNotExists

        # Update result with resolved paths
        $result.SourceDirectory = $resolvedSourceDir
        $result.OutputDirectory = $resolvedOutputDir

        # Display section header
        $modeText = if ($PrepareForAppSource) { "AppSource Submission" } else { "Build" }
        Write-SectionHeader "Preparing $AppType App Source for $modeText" -ForegroundColor Cyan -DecorationType Underline

        # Display information about the operation
        Write-InfoMessage "Starting source preparation with the following parameters:"
        Write-InfoMessage "  Mode: $($result.Mode)"
        Write-InfoMessage "  App Type: $AppType"
        Write-InfoMessage "  Source Directory: $resolvedSourceDir"
        Write-InfoMessage "  Output Directory: $resolvedOutputDir"
        if ($PrepareForAppSource) {
            Write-InfoMessage "  Replacement Source Path: $ReplacementSourcePath"
        }

        # Check if source directory exists
        if (-not (Test-Path -Path $resolvedSourceDir -PathType Container)) {
            throw "Source directory not found: $resolvedSourceDir"
        }

        if ($PrepareForAppSource) {
            # AppSource preparation mode
            Write-InfoMessage "=== AppSource Preparation Mode ==="

            # Step 1: Remove existing source files
            Write-InfoMessage "Removing existing source files from target app..."
            $removeResult = Remove-AppSourceFiles -TargetDirectory $resolvedOutputDir

            if (-not $removeResult.Success) {
                throw "Failed to remove existing source files: $($removeResult.Message)"
            }

            Write-InfoMessage $removeResult.Message
            $result.FilesRemoved = $removeResult.FilesRemoved
            $result.DirectoriesRemoved = $removeResult.DirectoriesRemoved

            # Step 2: Copy replacement files
            Write-InfoMessage "Copying replacement source files..."
            $copyResult = Copy-ReplacementFiles -ReplacementSourcePath $ReplacementSourcePath -TargetDirectory $resolvedOutputDir

            if (-not $copyResult.Success) {
                throw "Failed to copy replacement source files: $($copyResult.Message)"
            }

            Write-InfoMessage $copyResult.Message
            $result.FilesCopied = $copyResult.FilesCopied

        } else {
            # Build preparation mode (existing logic)
            Write-InfoMessage "=== Build Preparation Mode ==="

            # Check if we need to create a .gitignore file in the build directory
            $buildDirPath = $Config.OutputPaths.Build
            $resolvedBuildDir = Resolve-TDDPath -Path $buildDirPath -CreateIfNotExists

            # Create .gitignore file in the build directory root
            New-GitIgnoreFile -BuildDirectory $resolvedBuildDir

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

            # Copy logo file if referenced in app.json
            $appJsonPath = Join-Path -Path $resolvedOutputDir -ChildPath "app.json"
            Write-InfoMessage "Checking for logo file reference..."
            $logoResult = Copy-LogoFile -AppJsonPath $appJsonPath -SourceDirectory $resolvedSourceDir -OutputDirectory $resolvedOutputDir

            if (-not $logoResult.Success) {
                throw "Failed to copy logo file: $($logoResult.Message)"
            }

            Write-InfoMessage $logoResult.Message

            # Update result with logo information
            $result.LogoCopied = $logoResult.LogoCopied
            $result.LogoPath = $logoResult.LogoPath
        }

        # Validate app.json (common for both modes)
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
        $result.Message = "Successfully prepared $AppType app source for $modeText"

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
$result = Invoke-PrepareAppSource -Config $config -SourceDirectory $SourceDirectory -OutputDirectory $OutputDirectory -AppType $AppType -PrepareForAppSource:$PrepareForAppSource -ReplacementSourcePath $ReplacementSourcePath

# Return the result
return $result

#endregion