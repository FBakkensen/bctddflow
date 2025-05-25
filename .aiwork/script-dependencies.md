# PowerShell Script Dependencies Analysis

## Executive Summary

This document provides a comprehensive analysis of all dependencies and cross-references between PowerShell scripts in the `scripts` folder. The analysis identifies all dot-sourcing statements, script invocation calls, relative path references, and configuration file dependencies that will require updates during the folder restructuring process.

**Total Scripts Analyzed:** 13 PowerShell scripts + 1 configuration file
**Dependency Types Found:** 4 categories (dot-sourcing, script calls, config references, path dependencies)
**Critical Dependencies:** All scripts depend on Common-Functions.ps1 and most depend on Get-TDDConfiguration.ps1

## Dependency Categories

### 1. Dot-Sourcing Dependencies (`. script.ps1`)

**Common-Functions.ps1** - Required by ALL workflow scripts:
- `Initialize-TDDEnvironment.ps1` (Line 103-108)
- `Prepare-AppSource.ps1` (Line 84-89)
- `Compile-App.ps1` (Similar pattern)
- `Deploy-App.ps1` (Similar pattern)
- `Run-Tests.ps1` (Line 101-108)
- `View-TestResults.ps1` (Line 88-93)
- `SetupTestContainer.ps1` (Line 101-110)
- `Verify-Environment.ps1` (Line 64-70)

**Get-TDDConfiguration.ps1** - Required by most scripts:
- `Initialize-TDDEnvironment.ps1` (Line 111-116)
- `Prepare-AppSource.ps1` (Line 92-97)
- `Run-Tests.ps1` (Line 233-239)
- `View-TestResults.ps1` (Line 96-100)
- `Verify-Environment.ps1` (Line 73-78)

### 2. Script Invocation Calls (`& script.ps1` or `.\script.ps1`)

**Start-TDDSession.ps1** calls:
- `Initialize-TDDEnvironment.ps1` (Line 223)
- `Prepare-AppSource.ps1` (Line 362)
- `Compile-App.ps1` (Similar pattern for options 2-3)

**Start-TDDWorkflow.ps1** calls:
- `Prepare-AppSource.ps1` (Line 439)
- `Compile-App.ps1` (Workflow orchestration)
- `Deploy-App.ps1` (Workflow orchestration)
- `Run-Tests.ps1` (Workflow orchestration)
- `View-TestResults.ps1` (Line 632)

**Verify-Environment.ps1** calls:
- `Initialize-TDDEnvironment.ps1` (Line 196)

**SetupTestContainer.ps1** calls:
- `Get-TDDConfiguration.ps1` (Line 123, 133 - using `&` operator)

**View-TestResults.ps1** calls:
- `Get-TDDConfiguration.ps1` (Line 108 - using `&` operator)

### 3. Configuration File References

**TDDConfig.psd1** - Referenced by all scripts through Get-TDDConfiguration.ps1:

**Default Path Patterns:**
- Most scripts: `Join-Path -Path $scriptDir -ChildPath "TDDConfig.psd1"`
- SetupTestContainer.ps1: `Join-Path -Path $PSScriptRoot -ChildPath "TDDConfig.psd1"`
- Get-TDDConfiguration.ps1: Default parameter value with fallback logic

### 4. Relative Path Construction Patterns

**Script Directory Resolution:**
- All scripts use `$MyInvocation.MyCommand.Path` with `$PSCommandPath` fallback
- Hard-coded fallback: `"d:\repos\bctddflow\scripts"`
- Path construction: `Split-Path -Parent $scriptPath`

**Common Path Building Pattern:**
```powershell
$commonFunctionsPath = Join-Path -Path $scriptDir -ChildPath "Common-Functions.ps1"
$getTDDConfigPath = Join-Path -Path $scriptDir -ChildPath "Get-TDDConfiguration.ps1"
```

## Script-by-Script Dependency Analysis

### Entry Point Scripts (Root Level)

#### Start-TDDSession.ps1
- **Dot-sources:** Common-Functions.ps1, Get-TDDConfiguration.ps1
- **Calls:** Initialize-TDDEnvironment.ps1, Prepare-AppSource.ps1, Compile-App.ps1
- **Config:** TDDConfig.psd1 via Get-TDDConfiguration.ps1
- **Path Updates Needed:** All relative paths to moved scripts

#### Start-TDDWorkflow.ps1  
- **Dot-sources:** Common-Functions.ps1, Get-TDDConfiguration.ps1
- **Calls:** Prepare-AppSource.ps1, Compile-App.ps1, Deploy-App.ps1, Run-Tests.ps1, View-TestResults.ps1
- **Config:** TDDConfig.psd1 via Get-TDDConfiguration.ps1
- **Path Updates Needed:** All workflow script paths

#### Initialize-TDDEnvironment.ps1
- **Dot-sources:** Common-Functions.ps1, Get-TDDConfiguration.ps1
- **Calls:** None
- **Config:** TDDConfig.psd1 via Get-TDDConfiguration.ps1
- **Path Updates Needed:** Library script paths

### Workflow Scripts (Moving to workflow/ folder)

#### Prepare-AppSource.ps1
- **Dot-sources:** Common-Functions.ps1, Get-TDDConfiguration.ps1
- **Calls:** Get-TDDConfiguration.ps1 (with & operator)
- **Config:** TDDConfig.psd1 via Get-TDDConfiguration.ps1
- **Path Updates Needed:** Relative paths to lib/ folder

#### Compile-App.ps1
- **Dot-sources:** Common-Functions.ps1, Get-TDDConfiguration.ps1
- **Calls:** Get-TDDConfiguration.ps1 (with & operator)
- **Config:** TDDConfig.psd1 via Get-TDDConfiguration.ps1
- **Path Updates Needed:** Relative paths to lib/ folder

#### Deploy-App.ps1
- **Dot-sources:** Common-Functions.ps1, Get-TDDConfiguration.ps1
- **Calls:** Get-TDDConfiguration.ps1 (with & operator)
- **Config:** TDDConfig.psd1 via Get-TDDConfiguration.ps1
- **Path Updates Needed:** Relative paths to lib/ folder

#### Run-Tests.ps1
- **Dot-sources:** Common-Functions.ps1, Get-TDDConfiguration.ps1
- **Calls:** Get-TDDConfiguration.ps1 (with & operator)
- **Config:** TDDConfig.psd1 via Get-TDDConfiguration.ps1
- **Path Updates Needed:** Relative paths to lib/ folder

#### View-TestResults.ps1
- **Dot-sources:** Common-Functions.ps1, Get-TDDConfiguration.ps1
- **Calls:** Get-TDDConfiguration.ps1 (with & operator)
- **Config:** TDDConfig.psd1 via Get-TDDConfiguration.ps1
- **Path Updates Needed:** Relative paths to lib/ folder

### Internal Helper Scripts (Moving to internal/ folder)

#### Verify-Environment.ps1
- **Dot-sources:** Common-Functions.ps1, Get-TDDConfiguration.ps1
- **Calls:** Initialize-TDDEnvironment.ps1
- **Config:** TDDConfig.psd1 via Get-TDDConfiguration.ps1
- **Path Updates Needed:** Paths to lib/ and root scripts

#### SetupTestContainer.ps1
- **Dot-sources:** Common-Functions.ps1
- **Calls:** Get-TDDConfiguration.ps1 (with & operator, multiple times)
- **Config:** TDDConfig.psd1 via Get-TDDConfiguration.ps1
- **Path Updates Needed:** Paths to lib/ folder

### Library Scripts (Moving to lib/ folder)

#### Common-Functions.ps1
- **Dot-sources:** None
- **Calls:** None
- **Config:** None directly
- **Path Updates Needed:** None (no dependencies)

#### Get-TDDConfiguration.ps1
- **Dot-sources:** None (but references Common-Functions.ps1 in comments)
- **Calls:** None
- **Config:** TDDConfig.psd1 (default path logic)
- **Path Updates Needed:** Default config path to ../config/TDDConfig.psd1

## Cross-Reference Matrix

| Script | Common-Functions | Get-TDDConfig | TDDConfig.psd1 | Other Scripts |
|--------|------------------|---------------|----------------|---------------|
| Start-TDDSession.ps1 | ✓ (dot-source) | ✓ (dot-source) | ✓ (via Get-TDD) | Initialize, Prepare, Compile |
| Start-TDDWorkflow.ps1 | ✓ (dot-source) | ✓ (dot-source) | ✓ (via Get-TDD) | All workflow scripts |
| Initialize-TDDEnvironment.ps1 | ✓ (dot-source) | ✓ (dot-source) | ✓ (via Get-TDD) | None |
| Prepare-AppSource.ps1 | ✓ (dot-source) | ✓ (dot-source + call) | ✓ (via Get-TDD) | None |
| Compile-App.ps1 | ✓ (dot-source) | ✓ (dot-source + call) | ✓ (via Get-TDD) | None |
| Deploy-App.ps1 | ✓ (dot-source) | ✓ (dot-source + call) | ✓ (via Get-TDD) | None |
| Run-Tests.ps1 | ✓ (dot-source) | ✓ (dot-source + call) | ✓ (via Get-TDD) | None |
| View-TestResults.ps1 | ✓ (dot-source) | ✓ (dot-source + call) | ✓ (via Get-TDD) | None |
| Verify-Environment.ps1 | ✓ (dot-source) | ✓ (dot-source) | ✓ (via Get-TDD) | Initialize-TDDEnvironment |
| SetupTestContainer.ps1 | ✓ (dot-source) | ✓ (call only) | ✓ (via Get-TDD) | None |

## Path References Requiring Updates

### 1. Library Script References (All scripts → lib/ folder)
**Current Pattern:**
```powershell
$commonFunctionsPath = Join-Path -Path $scriptDir -ChildPath "Common-Functions.ps1"
$getTDDConfigPath = Join-Path -Path $scriptDir -ChildPath "Get-TDDConfiguration.ps1"
```

**New Pattern for Root Scripts:**
```powershell
$commonFunctionsPath = Join-Path -Path $scriptDir -ChildPath "lib\Common-Functions.ps1"
$getTDDConfigPath = Join-Path -Path $scriptDir -ChildPath "lib\Get-TDDConfiguration.ps1"
```

**New Pattern for Workflow Scripts:**
```powershell
$commonFunctionsPath = Join-Path -Path $scriptDir -ChildPath "..\lib\Common-Functions.ps1"
$getTDDConfigPath = Join-Path -Path $scriptDir -ChildPath "..\lib\Get-TDDConfiguration.ps1"
```

**New Pattern for Internal Scripts:**
```powershell
$commonFunctionsPath = Join-Path -Path $scriptDir -ChildPath "..\lib\Common-Functions.ps1"
$getTDDConfigPath = Join-Path -Path $scriptDir -ChildPath "..\lib\Get-TDDConfiguration.ps1"
```

### 2. Configuration File References
**Current Pattern in Get-TDDConfiguration.ps1:**
```powershell
[string]$ConfigPath = "scripts\TDDConfig.psd1"
```

**New Pattern:**
```powershell
[string]$ConfigPath = "..\config\TDDConfig.psd1"
```

### 3. Script Invocation Calls

**Root Scripts calling Workflow Scripts:**
- Current: `Join-Path -Path $scriptDir -ChildPath "Prepare-AppSource.ps1"`
- New: `Join-Path -Path $scriptDir -ChildPath "workflow\Prepare-AppSource.ps1"`

**Root Scripts calling Internal Scripts:**
- Current: `Join-Path -Path $scriptDir -ChildPath "Initialize-TDDEnvironment.ps1"`
- New: No change (Initialize-TDDEnvironment.ps1 stays in root)

**Internal Scripts calling Root Scripts:**
- Current: `Join-Path -Path $scriptDir -ChildPath "Initialize-TDDEnvironment.ps1"`
- New: `Join-Path -Path $scriptDir -ChildPath "..\Initialize-TDDEnvironment.ps1"`

## Impact Analysis

### High Impact Changes
1. **All workflow scripts** need library path updates (5 scripts)
2. **All internal scripts** need library path updates (2 scripts)
3. **Root scripts** need workflow and internal script path updates (3 scripts)
4. **Get-TDDConfiguration.ps1** needs config path update (1 script)

### Medium Impact Changes
1. **Cross-folder script calls** between internal and root scripts
2. **Configuration file loading** from new location

### Low Impact Changes
1. **Library scripts themselves** (no dependencies to update)
2. **Configuration file** (no script references)

## Validation Checklist

After restructuring, verify:
- [ ] All dot-sourcing statements resolve correctly
- [ ] All script invocation calls find target scripts
- [ ] Configuration file loading works from all locations
- [ ] No broken relative path references remain
- [ ] All scripts can execute independently
- [ ] Workflow orchestration still functions
- [ ] Error handling paths are correct

## Notes

1. **Script Directory Resolution:** All scripts use consistent pattern for finding their directory
2. **Fallback Paths:** Hard-coded fallback paths will need updating if repository structure changes
3. **Configuration Centralization:** All configuration access goes through Get-TDDConfiguration.ps1
4. **Error Handling:** Most scripts have proper error handling for missing dependencies
5. **Path Construction:** Consistent use of Join-Path for cross-platform compatibility

---
*Analysis completed: All dependencies identified and documented for restructuring implementation.*
