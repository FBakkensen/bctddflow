<#
.SYNOPSIS
    Compiles AL source code into a Business Central app package (.app file).
.DESCRIPTION
    This script compiles AL source code into a Business Central app package by:
    1. Taking parameters for app source directory, output directory, and app type (main/test)
    2. Using alc.exe on the host machine (not in the container) to compile the app
    3. Applying compiler options from the configuration (code analysis, treat warnings as errors)
    4. Outputting the compiled app file (.app) to the specified output directory
    5. Returning a strongly-typed [pscustomobject] with compilation results

    This script uses common utility functions from Common-Functions.ps1 and configuration
    from TDDConfig.psd1 for consistent functionality across the TDD workflow scripts.
.PARAMETER ConfigPath
    Path to the configuration file. Default is "scripts\TDDConfig.psd1" in the same directory as this script.
.PARAMETER AppSourceDirectory
    Path to the app source directory containing AL files. If not specified, uses the path from configuration based on AppType.
.PARAMETER OutputDirectory
    Path to the output directory where the compiled app file will be saved. If not specified, uses the path from configuration based on AppType.
.PARAMETER AppType
    Type of app to compile. Valid values are "Main" and "Test". Default is "Main".
.EXAMPLE
    .\scripts\Compile-App.ps1
    # Compiles the main app using default paths from configuration
.EXAMPLE
    .\scripts\Compile-App.ps1 -AppType "Test"
    # Compiles the test app using default paths from configuration
.EXAMPLE
    .\scripts\Compile-App.ps1 -AppSourceDirectory ".\build\app" -OutputDirectory ".\build\output" -AppType "Main"
    # Compiles the main app using specified paths
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
    [string]$AppSourceDirectory,

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

function Get-AlcPath {
    <#
    .SYNOPSIS
        Gets the path to the alc.exe compiler.
    .DESCRIPTION
        Attempts to find the alc.exe compiler in various locations.
        If the compiler is not found, attempts to download it using BcContainerHelper
        or extract it from Business Central artifacts.
    .PARAMETER DownloadIfMissing
        If specified, attempts to download or extract the compiler if it's not found.
    .OUTPUTS
        System.String. Returns the path to alc.exe if found or downloaded, $null otherwise.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$DownloadIfMissing
    )

    try {
        # Try to find alc.exe in common locations first
        $commonLocations = @(
            # BcContainerHelper default location
            "$env:USERPROFILE\.bccontainerhelper\alctools\alc.exe",
            # AL Language extension location (VS Code)
            "$env:USERPROFILE\.vscode\extensions\ms-dynamics-smb.al-*\bin\alc.exe",
            # Business Central container location
            "C:\ProgramData\BcContainerHelper\Extensions\*\bin\alc.exe"
        )

        foreach ($location in $commonLocations) {
            $alcFiles = Get-Item -Path $location -ErrorAction SilentlyContinue
            if ($alcFiles) {
                # If multiple matches, get the latest version
                $latestAlc = $alcFiles | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1

                # Check if alc.dll exists in the same directory
                $alcDir = Split-Path -Parent $latestAlc.FullName
                $alcDllPath = Join-Path -Path $alcDir -ChildPath "alc.dll"

                if (Test-Path -Path $alcDllPath -PathType Leaf) {
                    Write-InfoMessage "Found alc.exe at: $($latestAlc.FullName)"
                    return $latestAlc.FullName
                }
                else {
                    Write-WarningMessage "Found alc.exe at $($latestAlc.FullName) but alc.dll is missing. Will try to find a complete installation."
                }
            }
        }

        # Check if BcContainerHelper is available
        # Check if we should suppress verbose output from BcContainerHelper
        $suppressVerbose = $false
        if ($config.ScriptSettings -and $config.ScriptSettings.SuppressBcContainerHelperVerbose) {
            $suppressVerbose = $config.ScriptSettings.SuppressBcContainerHelperVerbose
        }

        if (Import-BcContainerHelperModule -SuppressVerbose:$suppressVerbose) {
            # Try to get alc.exe from BcContainerHelper
            if (Test-BcContainerHelperCommandAvailable -CommandName "Get-AlToolPath") {
                $alcPath = Get-AlToolPath
                if ($alcPath -and (Test-Path -Path $alcPath -PathType Leaf)) {
                    Write-InfoMessage "Found alc.exe using BcContainerHelper at: $alcPath"
                    return $alcPath
                }
            }
        }

        # If we get here, alc.exe was not found
        if ($DownloadIfMissing) {
            Write-InfoMessage "alc.exe not found in common locations. Attempting to download or extract..."

            # Create a directory for the compiler if it doesn't exist
            $alcToolsPath = Join-Path -Path $env:USERPROFILE -ChildPath ".bccontainerhelper\alctools"
            if (-not (Test-Path -Path $alcToolsPath -PathType Container)) {
                New-Item -Path $alcToolsPath -ItemType Directory -Force | Out-Null
            }

            $alcPath = Join-Path -Path $alcToolsPath -ChildPath "alc.exe"
            $alcDllPath = Join-Path -Path $alcToolsPath -ChildPath "alc.dll"

            # Check if alc.exe exists but alc.dll is missing
            if ((Test-Path -Path $alcPath -PathType Leaf) -and (-not (Test-Path -Path $alcDllPath -PathType Leaf))) {
                Write-WarningMessage "Found alc.exe at $alcPath but alc.dll is missing. Cleaning up incomplete installation..."
                Remove-Item -Path $alcPath -Force
            }

            # Try to find and extract alc.exe from Business Central artifacts
            Write-InfoMessage "Checking for Business Central artifacts in C:\bcartifacts.cache\sandbox..."

            # Check if the bcartifacts.cache directory exists
            if (Test-Path -Path "C:\bcartifacts.cache\sandbox" -PathType Container) {
                try {
                    # Find the highest version subdirectory
                    $versionDirs = Get-ChildItem -Path "C:\bcartifacts.cache\sandbox" -Directory |
                                   Where-Object { $_.Name -match "^\d+\.\d+\.\d+\.\d+$" } |
                                   Sort-Object -Property Name -Descending

                    if ($versionDirs -and $versionDirs.Count -gt 0) {
                        $highestVersionDir = $versionDirs[0]
                        Write-InfoMessage "Found Business Central artifacts version: $($highestVersionDir.Name)"

                        # Look for ALLanguage.vsix in the ModernDev subdirectory
                        $vsixSearchPaths = @(
                            # Common paths for ALLanguage.vsix
                            "$($highestVersionDir.FullName)\platform\ModernDev\program files\microsoft dynamics nav\*\al development environment\ALLanguage.vsix",
                            "$($highestVersionDir.FullName)\platform\ModernDev\ALLanguage.vsix",
                            "$($highestVersionDir.FullName)\ALLanguage.vsix"
                        )

                        $vsixFile = $null
                        foreach ($searchPath in $vsixSearchPaths) {
                            $vsixFiles = Get-Item -Path $searchPath -ErrorAction SilentlyContinue
                            if ($vsixFiles) {
                                $vsixFile = $vsixFiles | Select-Object -First 1
                                Write-InfoMessage "Found ALLanguage.vsix at: $($vsixFile.FullName)"
                                break
                            }
                        }

                        if ($vsixFile) {
                            # Create a temporary directory for extraction
                            $tempDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
                            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

                            try {
                                # Copy the VSIX file to the temp directory and rename it to .zip
                                $tempVsixPath = Join-Path -Path $tempDir -ChildPath "ALLanguage.vsix"
                                $tempZipPath = Join-Path -Path $tempDir -ChildPath "ALLanguage.zip"

                                Write-InfoMessage "Copying VSIX file to temporary location for extraction..."
                                Copy-Item -Path $vsixFile.FullName -Destination $tempVsixPath -Force

                                # Rename to .zip for extraction
                                Rename-Item -Path $tempVsixPath -NewName "ALLanguage.zip" -Force

                                # Extract the contents
                                Write-InfoMessage "Extracting VSIX file contents..."
                                Expand-Archive -Path $tempZipPath -DestinationPath $tempDir -Force

                                # Look for alc.exe in the extracted files
                                $extractedAlcPath = Get-ChildItem -Path $tempDir -Filter "alc.exe" -Recurse | Select-Object -First 1

                                if ($extractedAlcPath) {
                                    # Get the directory containing alc.exe
                                    $alcDir = Split-Path -Parent $extractedAlcPath.FullName

                                    # Copy alc.exe and all DLL files to the tools directory
                                    Write-InfoMessage "Found alc.exe in extracted files. Copying alc.exe and dependencies to tools directory..."

                                    # Create the tools directory if it doesn't exist
                                    if (-not (Test-Path -Path $alcToolsPath -PathType Container)) {
                                        New-Item -Path $alcToolsPath -ItemType Directory -Force | Out-Null
                                    }

                                    # Copy alc.exe
                                    Copy-Item -Path $extractedAlcPath.FullName -Destination $alcPath -Force

                                    # Copy all DLL files from the same directory
                                    $dllFiles = Get-ChildItem -Path $alcDir -Filter "*.dll" -File
                                    foreach ($dllFile in $dllFiles) {
                                        $dllDestPath = Join-Path -Path $alcToolsPath -ChildPath $dllFile.Name
                                        Copy-Item -Path $dllFile.FullName -Destination $dllDestPath -Force
                                        Write-InfoMessage "Copied dependency: $($dllFile.Name)"
                                    }

                                    # Copy all files from the 'Analyzers' subdirectory if it exists
                                    $analyzersDir = Join-Path -Path $alcDir -ChildPath "Analyzers"
                                    if (Test-Path -Path $analyzersDir -PathType Container) {
                                        $analyzersDestDir = Join-Path -Path $alcToolsPath -ChildPath "Analyzers"
                                        if (-not (Test-Path -Path $analyzersDestDir -PathType Container)) {
                                            New-Item -Path $analyzersDestDir -ItemType Directory -Force | Out-Null
                                        }

                                        $analyzerFiles = Get-ChildItem -Path $analyzersDir -File -Recurse
                                        foreach ($analyzerFile in $analyzerFiles) {
                                            $relativePath = $analyzerFile.FullName.Substring($analyzersDir.Length + 1)
                                            $analyzerDestPath = Join-Path -Path $analyzersDestDir -ChildPath $relativePath
                                            $analyzerDestDir = Split-Path -Parent $analyzerDestPath

                                            if (-not (Test-Path -Path $analyzerDestDir -PathType Container)) {
                                                New-Item -Path $analyzerDestDir -ItemType Directory -Force | Out-Null
                                            }

                                            Copy-Item -Path $analyzerFile.FullName -Destination $analyzerDestPath -Force
                                        }
                                        Write-InfoMessage "Copied Analyzers directory"
                                    }

                                    if (Test-Path -Path $alcPath -PathType Leaf) {
                                        Write-SuccessMessage "Successfully extracted alc.exe and dependencies from Business Central artifacts to: $alcToolsPath"

                                        # Clean up temporary files
                                        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

                                        return $alcPath
                                    }
                                }
                                else {
                                    Write-WarningMessage "Could not find alc.exe in the extracted files."
                                }
                            }
                            catch {
                                Write-WarningMessage "Failed to extract alc.exe from VSIX file: $_"
                            }
                            finally {
                                # Clean up temporary files
                                if (Test-Path -Path $tempDir -PathType Container) {
                                    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                                }
                            }
                        }
                        else {
                            Write-WarningMessage "Could not find ALLanguage.vsix in Business Central artifacts."
                        }
                    }
                    else {
                        Write-WarningMessage "No version directories found in C:\bcartifacts.cache\sandbox."
                    }
                }
                catch {
                    Write-WarningMessage "Error searching Business Central artifacts: $_"
                }
            }
            else {
                Write-WarningMessage "Business Central artifacts directory not found at C:\bcartifacts.cache\sandbox."
            }

            # If extraction from artifacts failed, try BcContainerHelper
            Write-InfoMessage "Attempting to find alc.exe from other sources..."

            if (Import-BcContainerHelperModule -SuppressVerbose:$suppressVerbose) {
                # Try to download alc.exe using BcContainerHelper
                if (Test-BcContainerHelperCommandAvailable -CommandName "Download-ALToolsPackage") {
                    try {
                        $alcToolsPath = Download-ALToolsPackage
                        if ($alcToolsPath -and (Test-Path -Path $alcToolsPath -PathType Container)) {
                            $alcPath = Join-Path -Path $alcToolsPath -ChildPath "alc.exe"
                            if (Test-Path -Path $alcPath -PathType Leaf) {
                                Write-SuccessMessage "Successfully downloaded alc.exe to: $alcPath"
                                return $alcPath
                            }
                        }
                    }
                    catch {
                        Write-WarningMessage "Failed to download alc.exe using BcContainerHelper: $_"
                    }
                }
            }

            # Provide detailed instructions for manual installation
            $instructions = @"
To manually install the AL Language compiler:

1. Install the AL Language extension in VS Code:
   - Open VS Code
   - Go to Extensions (Ctrl+Shift+X)
   - Search for 'AL Language'
   - Install the extension by Microsoft
   - Find alc.exe in the extension directory (typically in ~/.vscode/extensions/ms-dynamics-smb.al-*/bin/alc.exe)
   - Copy it to: $alcToolsPath

2. Or extract from Business Central artifacts:
   - Look in C:\bcartifacts.cache\sandbox\<version>\platform\ModernDev\program files\microsoft dynamics nav\<version>\al development environment\
   - Find ALLanguage.vsix
   - Rename it to .zip and extract
   - Find alc.exe in the extracted files (typically in \extension\bin\alc.exe)
   - Copy alc.exe AND all DLL files from the same directory to: $alcToolsPath
   - Also copy the 'Analyzers' subdirectory if it exists

3. Or use BcContainerHelper to download it:
   - Run PowerShell as Administrator
   - Install-Module BcContainerHelper -Force
   - Import-Module BcContainerHelper
   - Download-ALToolsPackage

4. Or extract it from a Business Central container:
   - Make sure you have a Business Central container running
   - Use the Copy-FileFromBcContainer cmdlet to copy alc.exe from the container
"@

            Write-ErrorMessage "Failed to download or extract alc.exe." $instructions
        }
        else {
            # Provide detailed instructions for manual installation
            $instructions = @"
To manually install the AL Language compiler:

1. Install the AL Language extension in VS Code:
   - Open VS Code
   - Go to Extensions (Ctrl+Shift+X)
   - Search for 'AL Language'
   - Install the extension by Microsoft
   - Find alc.exe in the extension directory (typically in ~/.vscode/extensions/ms-dynamics-smb.al-*/bin/alc.exe)
   - Copy it to: $env:USERPROFILE\.bccontainerhelper\alctools

2. Or extract from Business Central artifacts:
   - Look in C:\bcartifacts.cache\sandbox\<version>\platform\ModernDev\program files\microsoft dynamics nav\<version>\al development environment\
   - Find ALLanguage.vsix
   - Rename it to .zip and extract
   - Find alc.exe in the extracted files (typically in \extension\bin\alc.exe)
   - Copy alc.exe AND all DLL files from the same directory to: $env:USERPROFILE\.bccontainerhelper\alctools
   - Also copy the 'Analyzers' subdirectory if it exists

3. Or use BcContainerHelper to download it:
   - Run PowerShell as Administrator
   - Install-Module BcContainerHelper -Force
   - Import-Module BcContainerHelper
   - Download-ALToolsPackage

4. Or extract it from a Business Central container:
   - Make sure you have a Business Central container running
   - Use the Copy-FileFromBcContainer cmdlet to copy alc.exe from the container
"@

            Write-ErrorMessage "alc.exe not found in common locations." $instructions
        }

        return $null
    }
    catch {
        Write-ErrorMessage "Error finding alc.exe: $_"
        return $null
    }
}

function Get-AppJsonInfo {
    <#
    .SYNOPSIS
        Gets information from the app.json file.
    .DESCRIPTION
        Reads and parses the app.json file to extract information needed for compilation.
    .PARAMETER AppJsonPath
        Path to the app.json file.
    .OUTPUTS
        PSCustomObject. Returns an object with app.json information.
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
        AppName = ""
        Publisher = ""
        Version = ""
        OutputFileName = ""
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
        $result.AppName = $appJsonContent.name
        $result.Publisher = $appJsonContent.publisher
        $result.Version = $appJsonContent.version

        # Create output file name
        $sanitizedPublisher = $appJsonContent.publisher -replace '[^a-zA-Z0-9]', ''
        $sanitizedName = $appJsonContent.name -replace '[^a-zA-Z0-9]', ''
        $result.OutputFileName = "$($sanitizedPublisher)_$($sanitizedName)_$($appJsonContent.version).app"

        return $result
    }
    catch {
        $result.Message = "Error parsing app.json: $_"
        return $result
    }
}

function Invoke-AlcCompiler {
    <#
    .SYNOPSIS
        Invokes the alc.exe compiler to compile an AL app.
    .DESCRIPTION
        Executes alc.exe with the appropriate parameters to compile an AL app.
    .PARAMETER AlcPath
        Path to the alc.exe compiler.
    .PARAMETER SourcePath
        Path to the source directory containing AL files.
    .PARAMETER OutputPath
        Path to the output file (.app).
    .PARAMETER CompilationOptions
        Hashtable of compilation options.
    .PARAMETER Config
        The configuration object containing settings for the TDD workflow.
    .OUTPUTS
        PSCustomObject. Returns an object with compilation results.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AlcPath,

        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter(Mandatory = $true)]
        [hashtable]$CompilationOptions,

        [Parameter(Mandatory = $false)]
        [hashtable]$Config
    )

    $result = [PSCustomObject]@{
        Success = $false
        Message = ""
        OutputPath = $OutputPath
        ErrorOutput = ""
        WarningCount = 0
        ErrorCount = 0
    }

    try {
        # Build the command line arguments
        $arguments = @(
            "/project:""$SourcePath""",
            "/out:""$OutputPath"""
        )

        # Add package cache path from .alpackages directory
        $alPackagesPath = Join-Path -Path $SourcePath -ChildPath ".alpackages"
        if (Test-Path -Path $alPackagesPath -PathType Container) {
            Write-InfoMessage "Using package cache from: $alPackagesPath"
            $arguments += "/packagecachepath:""$alPackagesPath"""
        } else {
            Write-WarningMessage "No .alpackages directory found at: $alPackagesPath"

            # Try to find .alpackages in parent directories
            $sourceParentDir = Split-Path -Parent $SourcePath
            $parentAlPackagesPath = Join-Path -Path $sourceParentDir -ChildPath ".alpackages"

            if (Test-Path -Path $parentAlPackagesPath -PathType Container) {
                Write-InfoMessage "Using package cache from parent directory: $parentAlPackagesPath"
                $arguments += "/packagecachepath:""$parentAlPackagesPath"""
            } else {
                # Try app and test directories
                $appAlPackagesPath = Join-Path -Path (Resolve-TDDPath -Path $Config.SourcePaths.App) -ChildPath ".alpackages"
                $testAlPackagesPath = Join-Path -Path (Resolve-TDDPath -Path $Config.SourcePaths.Test) -ChildPath ".alpackages"

                # Determine which package cache to use based on the app type
                $appType = if ($SourcePath -like "*\test*") { "Test" } else { "Main" }

                # Create a list of package cache paths to use
                $packageCachePaths = @()

                if ($appType -eq "Test" -and (Test-Path -Path $testAlPackagesPath -PathType Container)) {
                    # For test app, ensure the compiled main app is available in the package cache
                    $mainAppOutputPath = Join-Path -Path (Resolve-TDDPath -Path $Config.OutputPaths.AppOutput) -ChildPath "*.app"
                    $mainAppFiles = Get-ChildItem -Path $mainAppOutputPath -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*9AAdvancedManufacturingProjectBased*" }

                    if ($mainAppFiles) {
                        $latestMainApp = $mainAppFiles | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
                        $targetPath = Join-Path -Path $testAlPackagesPath -ChildPath $latestMainApp.Name

                        # Copy the compiled main app to test package cache if it doesn't exist or is older
                        if (-not (Test-Path -Path $targetPath) -or (Get-Item -Path $targetPath).LastWriteTime -lt $latestMainApp.LastWriteTime) {
                            Write-InfoMessage "Copying compiled main app to test package cache: $($latestMainApp.Name)"
                            Copy-Item -Path $latestMainApp.FullName -Destination $targetPath -Force
                        }
                    } else {
                        Write-WarningMessage "No compiled main app found in output directory. Test compilation may fail due to missing dependencies."
                    }

                    # For test app, use test\.alpackages first
                    Write-InfoMessage "Using package cache from test directory: $testAlPackagesPath"
                    $packageCachePaths += $testAlPackagesPath
                }

                if (Test-Path -Path $appAlPackagesPath -PathType Container) {
                    # Also use app\.alpackages for both app types
                    Write-InfoMessage "Using package cache from app directory: $appAlPackagesPath"
                    $packageCachePaths += $appAlPackagesPath
                }

                if ($packageCachePaths.Count -gt 0) {
                    # Join all package cache paths with semicolons
                    $arguments += "/packagecachepath:""$($packageCachePaths -join ';')"""
                } else {
                    Write-WarningMessage "No .alpackages directory found in app or test directories. Compilation may fail due to missing dependencies."
                }
            }
        }

        # Check the version of alc.exe to determine which options to use
        $alcVersionInfo = Get-Item -Path $AlcPath | ForEach-Object { $_.VersionInfo }
        $alcVersionString = if ($alcVersionInfo -and $alcVersionInfo.ProductVersion) {
            $alcVersionInfo.ProductVersion
        } else {
            "0.0.0.0"
        }

        # Extract just the version part (remove any build info after +)
        if ($alcVersionString -match "^(\d+\.\d+\.\d+\.\d+)") {
            $alcVersionString = $matches[1]
        } elseif ($alcVersionString -match "^(\d+\.\d+\.\d+)") {
            $alcVersionString = $matches[1]
        }

        try {
            $alcVersion = [version]$alcVersionString
        } catch {
            Write-WarningMessage "Could not parse AL compiler version: $alcVersionString. Using default options."
            $alcVersion = [version]"0.0.0.0"
        }

        Write-InfoMessage "AL Compiler version: $alcVersionString"

        # For newer versions of alc.exe (version 3.0 and above), use different option format
        # Version 15.0 is older than 3.0 in terms of feature set
        if ($alcVersion -ge [version]"3.0" -and $alcVersion.Major -lt 10) {
            # Add compilation options
            if ($CompilationOptions.CodeAnalysis -eq $true) {
                $arguments += "/analyzer+"
            } else {
                $arguments += "/analyzer-"
            }

            if ($CompilationOptions.GenerateReportLayout -eq $true) {
                $arguments += "/generatelayout+"
            } else {
                $arguments += "/generatelayout-"
            }

            if ($CompilationOptions.TreatWarningsAsErrors -eq $true) {
                $arguments += "/warnaserror+"
            } else {
                $arguments += "/warnaserror-"
            }

            # Add rule options
            if ($CompilationOptions.EnableCodeCop -eq $true) {
                $arguments += "/ruleset:CodeCop"
            }

            if ($CompilationOptions.EnableAppSourceCop -eq $true) {
                $arguments += "/ruleset:AppSourceCop"
            }

            if ($CompilationOptions.EnablePerTenantExtensionCop -eq $true) {
                $arguments += "/ruleset:PerTenantExtensionCop"
            }

            if ($CompilationOptions.EnableUICop -eq $true) {
                $arguments += "/ruleset:UICop"
            }
        } else {
            # For older versions, use simpler options
            if ($CompilationOptions.TreatWarningsAsErrors -eq $true) {
                $arguments += "/errorOnWarnings"
            }

            # For older versions, we need to check if the ruleset files exist
            # Try to find the ruleset files in the compiler directory
            $alcDir = Split-Path -Parent $AlcPath
            $analyzersDir = Join-Path -Path $alcDir -ChildPath "Analyzers"

            # Check if we have any ruleset files
            $hasRulesets = Test-Path -Path $analyzersDir -PathType Container

            if ($hasRulesets) {
                # Add rule options individually
                if ($CompilationOptions.EnableCodeCop -eq $true) {
                    $codeCopPath = Join-Path -Path $analyzersDir -ChildPath "CodeCop.dll"
                    if (Test-Path -Path $codeCopPath -PathType Leaf) {
                        $arguments += "/r:$codeCopPath"
                    }
                }

                if ($CompilationOptions.EnableAppSourceCop -eq $true) {
                    $appSourceCopPath = Join-Path -Path $analyzersDir -ChildPath "AppSourceCop.dll"
                    if (Test-Path -Path $appSourceCopPath -PathType Leaf) {
                        $arguments += "/r:$appSourceCopPath"
                    }
                }

                if ($CompilationOptions.EnablePerTenantExtensionCop -eq $true) {
                    $perTenantExtensionCopPath = Join-Path -Path $analyzersDir -ChildPath "PerTenantExtensionCop.dll"
                    if (Test-Path -Path $perTenantExtensionCopPath -PathType Leaf) {
                        $arguments += "/r:$perTenantExtensionCopPath"
                    }
                }
            } else {
                # Skip rulesets if we don't have them
                Write-WarningMessage "No ruleset files found in $analyzersDir. Skipping code analysis."
            }
        }

        # Execute the compiler
        Write-InfoMessage "Executing alc.exe with arguments: $($arguments -join ' ')"

        $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processStartInfo.FileName = $AlcPath
        $processStartInfo.Arguments = $arguments -join ' '
        $processStartInfo.RedirectStandardOutput = $true
        $processStartInfo.RedirectStandardError = $true
        $processStartInfo.UseShellExecute = $false
        $processStartInfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processStartInfo
        $process.Start() | Out-Null

        $outputData = $process.StandardOutput.ReadToEnd()
        $errorData = $process.StandardError.ReadToEnd()

        $process.WaitForExit()
        $exitCode = $process.ExitCode

        # Process the results
        if ($exitCode -eq 0) {
            $result.Success = $true
            $result.Message = "Compilation successful. Output file: $OutputPath"

            # Count warnings
            $warningMatches = [regex]::Matches($outputData, "warning AL[0-9]+")
            $result.WarningCount = $warningMatches.Count

            Write-SuccessMessage $result.Message
        } else {
            $result.Success = $false

            # Check if there's any error data
            if (-not [string]::IsNullOrWhiteSpace($errorData)) {
                $result.Message = "Compilation failed with exit code $exitCode"
                $result.ErrorOutput = $errorData

                # Count errors
                $errorMatches = [regex]::Matches($errorData, "error AL[0-9]+")
                $result.ErrorCount = $errorMatches.Count

                Write-ErrorMessage $result.Message
                Write-ErrorMessage $errorData
            }
            # Check if there's any output data that might contain errors
            elseif (-not [string]::IsNullOrWhiteSpace($outputData)) {
                $result.Message = "Compilation failed with exit code $exitCode"
                $result.ErrorOutput = $outputData

                # Count errors in output data
                $errorMatches = [regex]::Matches($outputData, "error AL[0-9]+")
                $result.ErrorCount = $errorMatches.Count

                Write-ErrorMessage $result.Message
                Write-ErrorMessage $outputData
            }
            else {
                # If no error data is available, check if the compiler exists and has all dependencies
                $alcPath = $processStartInfo.FileName
                $alcDir = Split-Path -Parent $alcPath
                $alcDllPath = Join-Path -Path $alcDir -ChildPath "alc.dll"

                if (-not (Test-Path -Path $alcDllPath -PathType Leaf)) {
                    $result.Message = "Compilation failed: alc.dll is missing from the compiler directory. The AL compiler installation appears to be incomplete."
                    $result.ErrorOutput = "Missing dependency: alc.dll not found in $alcDir"
                }
                else {
                    $result.Message = "Compilation failed with exit code $exitCode. No error output was captured."
                    $result.ErrorOutput = "No error details available. Check if the app source directory contains valid AL code."
                }

                Write-ErrorMessage $result.Message
            }
        }

        return $result
    }
    catch {
        $result.Success = $false
        $result.Message = "Error executing alc.exe: $_"
        $result.ErrorOutput = $_.Exception.Message

        Write-ErrorMessage $result.Message
        return $result
    }
}

function Invoke-CompileApp {
    <#
    .SYNOPSIS
        Main function to compile an AL app.
    .DESCRIPTION
        Compiles an AL app using alc.exe and returns the results.
    .PARAMETER Config
        The configuration object.
    .PARAMETER AppSourceDirectory
        Path to the app source directory containing AL files.
    .PARAMETER OutputDirectory
        Path to the output directory where the compiled app file will be saved.
    .PARAMETER AppType
        Type of app to compile. Valid values are "Main" and "Test".
    .OUTPUTS
        PSCustomObject. Returns an object with the results of the operation.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $false)]
        [string]$AppSourceDirectory,

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
        AppSourceDirectory = $null
        OutputDirectory = $null
        OutputFile = $null
        AppName = ""
        Publisher = ""
        Version = ""
        WarningCount = 0
        ErrorCount = 0
        Timestamp = Get-Date
    }

    try {
        # Determine source and output directories based on app type
        if ([string]::IsNullOrWhiteSpace($AppSourceDirectory)) {
            if ($AppType -eq "Main") {
                $AppSourceDirectory = $Config.OutputPaths.AppSource
            } else {
                $AppSourceDirectory = $Config.OutputPaths.TestSource
            }
        }

        if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
            $OutputDirectory = $Config.OutputPaths.AppOutput
        }

        # Resolve paths
        $resolvedSourceDir = Resolve-TDDPath -Path $AppSourceDirectory
        $resolvedOutputDir = Resolve-TDDPath -Path $OutputDirectory -CreateIfNotExists

        # Update result with resolved paths
        $result.AppSourceDirectory = $resolvedSourceDir
        $result.OutputDirectory = $resolvedOutputDir

        # Display section header
        Write-SectionHeader "Compiling $AppType App" -ForegroundColor Cyan -DecorationType Underline

        # Display information about the operation
        Write-InfoMessage "Starting compilation with the following parameters:"
        Write-InfoMessage "  App Type: $AppType"
        Write-InfoMessage "  Source Directory: $resolvedSourceDir"
        Write-InfoMessage "  Output Directory: $resolvedOutputDir"

        # Check if source directory exists
        if (-not (Test-Path -Path $resolvedSourceDir -PathType Container)) {
            throw "Source directory not found: $resolvedSourceDir"
        }

        # Get app.json information
        $appJsonPath = Join-Path -Path $resolvedSourceDir -ChildPath "app.json"
        Write-InfoMessage "Reading app.json..."
        $appJsonInfo = Get-AppJsonInfo -AppJsonPath $appJsonPath

        if (-not $appJsonInfo.Valid) {
            throw "app.json validation failed: $($appJsonInfo.Message)"
        }

        Write-InfoMessage "app.json validation passed"
        Write-InfoMessage "  App Name: $($appJsonInfo.AppName)"
        Write-InfoMessage "  Publisher: $($appJsonInfo.Publisher)"
        Write-InfoMessage "  Version: $($appJsonInfo.Version)"

        # Update result with app information
        $result.AppName = $appJsonInfo.AppName
        $result.Publisher = $appJsonInfo.Publisher
        $result.Version = $appJsonInfo.Version

        # Get alc.exe path
        $alcPath = Get-AlcPath -DownloadIfMissing
        if (-not $alcPath) {
            throw "alc.exe not found. Please install the AL Language extension in VS Code or use BcContainerHelper to download the compiler."
        }

        # Verify that alc.dll exists alongside alc.exe
        $alcDir = Split-Path -Parent $alcPath
        $alcDllPath = Join-Path -Path $alcDir -ChildPath "alc.dll"
        if (-not (Test-Path -Path $alcDllPath -PathType Leaf)) {
            throw "alc.dll not found in $alcDir. The AL compiler installation appears to be incomplete. Please reinstall the AL Language extension or use BcContainerHelper to download the compiler."
        }

        # Create output file path
        $outputFilePath = Join-Path -Path $resolvedOutputDir -ChildPath $appJsonInfo.OutputFileName
        $result.OutputFile = $outputFilePath

        # Compile the app
        Write-InfoMessage "Compiling app..."
        $compilationResult = Invoke-AlcCompiler -AlcPath $alcPath -SourcePath $resolvedSourceDir -OutputPath $outputFilePath -CompilationOptions $Config.Compilation -Config $Config

        # Update result with compilation information
        $result.Success = $compilationResult.Success
        $result.WarningCount = $compilationResult.WarningCount
        $result.ErrorCount = $compilationResult.ErrorCount

        if ($compilationResult.Success) {
            $result.Message = "Successfully compiled $AppType app: $($appJsonInfo.OutputFileName)"
            Write-SuccessMessage $result.Message
        } else {
            $result.Message = "Failed to compile $AppType app: $($compilationResult.Message)"
            Write-ErrorMessage $result.Message
        }
    }
    catch {
        # Handle any unexpected errors
        $result.Success = $false
        $result.Message = "An error occurred while compiling app: $_"

        Write-ErrorMessage $result.Message
    }

    return $result
}

#endregion

#region Main Script Execution

# Display script header
Write-SectionHeader "Compile App" -ForegroundColor Cyan -DecorationType Box

# Execute the main function
$result = Invoke-CompileApp -Config $config -AppSourceDirectory $AppSourceDirectory -OutputDirectory $OutputDirectory -AppType $AppType

# Return the result
return $result

#endregion
