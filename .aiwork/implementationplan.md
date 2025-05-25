# Scripts Folder Restructuring Implementation Plan

## Overview

This plan outlines the step-by-step process to restructure the `scripts` folder from a flat organization to a hierarchical structure that clearly separates user-facing entry points from internal implementation details. The goal is to improve usability, maintainability, and discoverability while preserving all existing functionality.

## Current Structure Analysis

The current flat structure contains:
- **Entry Points**: `Start-TDDSession.ps1`, `Start-TDDWorkflow.ps1`, `Initialize-TDDEnvironment.ps1`
- **Workflow Steps**: `Prepare-AppSource.ps1`, `Compile-App.ps1`, `Deploy-App.ps1`, `Run-Tests.ps1`, `View-TestResults.ps1`
- **Internal Helpers**: `Verify-Environment.ps1`, `SetupTestContainer.ps1`, `Common-Functions.ps1`, `Get-TDDConfiguration.ps1`
- **Configuration**: `TDDConfig.psd1`, `Script-Template.ps1`

## Target Structure

```
scripts/
├── Start-TDDSession.ps1          # Interactive session interface
├── Start-TDDWorkflow.ps1         # Complete workflow orchestrator
├── Initialize-TDDEnvironment.ps1 # Environment setup entry point
├── lib/                          # Core library functions
│   ├── Common-Functions.ps1      # Utility functions
│   └── Get-TDDConfiguration.ps1  # Configuration management
├── workflow/                     # Individual workflow step scripts
│   ├── Prepare-AppSource.ps1     # Source preparation
│   ├── Compile-App.ps1           # App compilation
│   ├── Deploy-App.ps1            # App deployment
│   ├── Run-Tests.ps1             # Test execution
│   └── View-TestResults.ps1      # Results viewing
├── internal/                     # Internal helper scripts
│   ├── Verify-Environment.ps1    # Environment verification
│   └── SetupTestContainer.ps1    # Container setup
└── config/                       # Configuration and templates
    ├── TDDConfig.psd1            # Configuration data
    └── Script-Template.ps1       # Script development template
```

## Implementation Tasks

### Phase 1: Preparation and Analysis

#### 1. [x] Create backup of current scripts folder
**Prompt:**
```
Create a backup copy of the entire scripts folder by copying it to a new folder named `scripts.backup` in the same directory. This ensures we can restore the original structure if needed during the restructuring process.
```
**Verification:**
- Confirm `scripts.backup` folder exists with all original files
- Verify all files in backup are identical to originals
- Test that original scripts still work from their current locations

#### 2. [x] Analyze all script dependencies and cross-references
**Prompt:**
```
Analyze all PowerShell scripts in the scripts folder to identify:
1. All dot-sourcing statements (`. .\path\to\script.ps1`)
2. All script invocation calls (`& .\path\to\script.ps1` or `.\script.ps1`)
3. All relative path references to other scripts
4. Configuration file path references
Create a detailed dependency map in markdown file called `script-dependencies.md` in the folder `.aiwork` showing which scripts call which other scripts and document all path references that will need updating.
```
**Verification:**
- Document shows complete dependency map
- All dot-sourcing statements are identified
- All script calls are documented
- All relative paths are catalogued
- No dependencies are missed

### Phase 2: Create New Folder Structure

#### 3. [x] Create new folder structure
**Prompt:**
```
Create the new folder structure within the scripts directory:
- Create `scripts\lib\` folder for library functions
- Create `scripts\workflow\` folder for workflow step scripts
- Create `scripts\internal\` folder for internal helper scripts
- Create `scripts\config\` folder for configuration and templates
Ensure all folders are created with proper permissions and verify they exist.
```
**Verification:**
- All four new folders exist in scripts directory
- Folders have appropriate permissions
- No existing files are affected
- Original flat structure remains intact

#### 4. [x] Move library functions to lib folder
**Prompt:**
```
Move the following scripts to the `scripts\lib\` folder:
- `Common-Functions.ps1`
- `Get-TDDConfiguration.ps1`
Update any internal path references within these scripts to work from their new location. Test that the moved scripts can still be loaded and their functions work correctly.
```
**Verification:**
- Both scripts exist in `scripts\lib\` folder
- Original locations no longer contain these files
- Scripts can be dot-sourced from new location
- All internal path references are corrected
- Functions work correctly when called

#### 5. [x] Move workflow scripts to workflow folder
**Prompt:**
```
Move the following scripts to the `scripts\workflow\` folder:
- `Prepare-AppSource.ps1`
- `Compile-App.ps1`
- `Deploy-App.ps1`
- `Run-Tests.ps1`
- `View-TestResults.ps1`
Update any internal path references within these scripts to work from their new location.
```
**Verification:**
- All five scripts exist in `scripts\workflow\` folder
- Original locations no longer contain these files
- All internal path references are updated
- Scripts can be executed from new location
- No functionality is broken

#### 6. [x] Move internal helper scripts to internal folder
**Prompt:**
```
Move the following scripts to the `scripts\internal\` folder:
- `Verify-Environment.ps1`
- `SetupTestContainer.ps1`
Update any internal path references within these scripts to work from their new location.
```
**Verification:**
- Both scripts exist in `scripts\internal\` folder
- Original locations no longer contain these files
- All internal path references are updated
- Scripts can be executed from new location
- Dependencies on other scripts still work

#### 7. [ ] Move configuration files to config folder
**Prompt:**
```
Move the following files to the `scripts\config\` folder:
- `TDDConfig.psd1`
- `Script-Template.ps1`
Update any scripts that reference these files to use the new paths.
```
**Verification:**
- Both files exist in `scripts\config\` folder
- Original locations no longer contain these files
- All references to configuration file are updated
- Configuration loading still works correctly
- Template is accessible from new location

### Phase 3: Update Script References

#### 8. [ ] Update dot-sourcing statements in all remaining root scripts
**Prompt:**
```
Update the dot-sourcing statements in the root-level scripts to reference the new locations:
- `Start-TDDSession.ps1`
- `Start-TDDWorkflow.ps1`
- `Initialize-TDDEnvironment.ps1`
Update all references to `Common-Functions.ps1` and `Get-TDDConfiguration.ps1` to use `lib\` folder paths.
```
**Verification:**
- All dot-sourcing statements use correct new paths
- Scripts load successfully without errors
- All functions from Common-Functions.ps1 are available
- Configuration loading works correctly
- No broken references remain

#### 9. [ ] Update script calls from root scripts to moved scripts
**Prompt:**
```
Update all script invocation calls in root-level scripts to reference the new locations:
- Update calls to workflow scripts to use `workflow\` folder
- Update calls to internal scripts to use `internal\` folder
- Update any configuration file references to use `config\` folder
Test that all script calls work correctly from the updated paths.
```
**Verification:**
- All script calls use correct new paths
- Scripts execute successfully from new locations
- No "file not found" errors occur
- All functionality works as expected
- Workflow orchestration still functions

#### 10. [ ] Update cross-references between moved scripts
**Prompt:**
```
Update any cross-references between scripts that have been moved to different folders:
- Update workflow scripts that call other workflow scripts
- Update internal scripts that reference each other
- Update any remaining relative path references
Ensure all inter-script communication works correctly.
```
**Verification:**
- All cross-references use correct relative paths
- Scripts can successfully call each other
- No broken dependencies exist
- All script chains execute properly
- Error handling paths work correctly

### Phase 4: Configuration and Path Updates

#### 11. [ ] Update configuration file paths in TDDConfig.psd1
**Prompt:**
```
Review and update the `TDDConfig.psd1` file (now in `config\` folder) to ensure all path references are still valid:
- Check if any paths reference script locations
- Update relative paths if needed
- Verify all configuration settings work with new structure
Test configuration loading from various script locations.
```
**Verification:**
- Configuration file loads successfully from new location
- All path references in config are valid
- Scripts can access configuration from any folder level
- No configuration-related errors occur
- All settings work as expected

#### 12. [ ] Update Get-TDDConfiguration.ps1 default paths
**Prompt:**
```
Update the `Get-TDDConfiguration.ps1` script to handle the new default path for the configuration file:
- Update default ConfigPath parameter to reference `config\TDDConfig.psd1`
- Ensure the script can find the config file when called from different locations
- Test configuration loading from all script locations
```
**Verification:**
- Default configuration path works correctly
- Script finds config file when called from any location
- No hardcoded paths cause issues
- Configuration loading is consistent
- Error messages provide correct paths

### Phase 5: Testing and Validation

#### 13. [ ] Test all entry point scripts individually
**Prompt:**
```
Test each root-level entry point script individually to ensure they work correctly with the new structure:
- Test `Start-TDDSession.ps1` - verify interactive menu works
- Test `Start-TDDWorkflow.ps1` - verify workflow orchestration works
- Test `Initialize-TDDEnvironment.ps1` - verify environment setup works
Check that all functions, script calls, and dependencies work correctly.
```
**Verification:**
- All three entry point scripts execute without errors
- Interactive functionality works correctly
- All script dependencies are resolved
- Workflow orchestration functions properly
- Environment setup completes successfully

#### 14. [ ] Test workflow scripts individually
**Prompt:**
```
Test each workflow script individually from their new location in the `workflow\` folder:
- Test each script can be called directly
- Test each script can load its dependencies correctly
- Verify all parameters and functionality work as expected
- Check error handling and reporting work correctly
```
**Verification:**
- All workflow scripts execute successfully
- Dependencies load correctly from new paths
- Parameters work as expected
- Error handling functions properly
- Output and logging work correctly

#### 15. [ ] Test complete workflow end-to-end
**Prompt:**
```
Perform a complete end-to-end test of the TDD workflow using the restructured scripts:
- Run a complete workflow from environment setup to test execution
- Test both successful scenarios and error conditions
- Verify all script interactions work correctly
- Check that all output and logging functions properly
```
**Verification:**
- Complete workflow executes successfully
- All script interactions work correctly
- Error conditions are handled properly
- Output and logging are complete and accurate
- No functionality is lost in restructuring

#### 16. [ ] Validate backward compatibility scenarios
**Prompt:**
```
Test scenarios that might break backward compatibility:
- Test if any external scripts or processes call the moved scripts
- Check if any documentation examples still work
- Verify that existing user workflows are not broken
- Test edge cases and error scenarios
```
**Verification:**
- No external dependencies are broken
- Documentation examples work or are documented as changed
- User workflows function correctly
- Edge cases are handled properly
- Error scenarios work as expected

### Phase 6: Documentation and Cleanup

#### 17. [ ] Update the TDD workflow plan document
**Prompt:**
```
Update the `tdd-workflow-plan.md` file to reflect the new script structure:
- Update all script paths in examples and verification steps
- Update all references to script locations
- Add notes about the new folder structure
- Update any installation or setup instructions
Ensure all documentation is accurate and reflects the new organization.
```
**Verification:**
- All script paths in documentation are updated
- Examples use correct new paths
- Installation instructions are accurate
- No outdated references remain
- Documentation is clear and complete

#### 18. [ ] Create migration guide for existing users
**Prompt:**
```
Create a migration guide document named `MIGRATION.md` in the `.aiwork` folder that explains:
- What changed in the restructuring
- How to update existing scripts or processes that reference the old paths
- Mapping of old paths to new paths
- Any breaking changes and how to address them
- Benefits of the new structure
```
**Verification:**
- Migration guide is comprehensive and clear
- All path changes are documented
- Breaking changes are clearly identified
- Solutions for common issues are provided
- Benefits are clearly explained

#### 19. [ ] Update README or setup documentation
**Prompt:**
```
Update any README files or setup documentation to reflect the new structure:
- Update script execution examples
- Update folder structure documentation
- Add explanation of the new organization
- Update any quick-start guides or tutorials
```
**Verification:**
- All documentation reflects new structure
- Examples use correct paths
- Quick-start guides work correctly
- New organization is explained clearly
- Setup instructions are accurate

#### 20. [ ] Clean up and finalize structure
**Prompt:**
```
Perform final cleanup and validation:
- Remove the backup folder if all tests pass
- Verify no orphaned files remain
- Confirm all scripts are in their correct locations
- Run final validation tests
- Document the completed restructuring
```
**Verification:**
- No backup files remain (unless intentionally kept)
- All scripts are in correct locations
- No orphaned or duplicate files exist
- All functionality works correctly
- Restructuring is complete and documented

## Success Criteria

The restructuring is considered successful when:

1. **Functionality Preservation**: All existing functionality works exactly as before
2. **Improved Organization**: Scripts are logically organized by their role and usage
3. **Clear Entry Points**: Users can easily identify which scripts to run
4. **Maintainability**: The structure is easier to navigate and maintain
5. **Documentation Accuracy**: All documentation reflects the new structure
6. **No Breaking Changes**: Existing workflows continue to function
7. **Better User Experience**: New users can understand the structure more easily

## Rollback Plan

If issues are encountered during implementation:

1. Stop the restructuring process
2. Restore from the backup created in task 1
3. Analyze the issues and adjust the plan
4. Resume implementation with corrected approach

## Benefits of New Structure

- **Clear separation** of user-facing vs internal scripts
- **Logical grouping** of related functionality
- **Improved discoverability** for new users
- **Better maintainability** for developers
- **Professional organization** following industry standards
- **Easier navigation** and understanding of the codebase
