# AL-Go Per Tenant Extension Template

## Overview

This is a template repository for managing AppSource Apps for Business Central using the AL-Go framework. Key features include:

- **GitHub Actions Workflows** for CI/CD, pull requests, and app creation
- **PowerPlatform Integration** with workflows for building, deploying, and syncing changes
- **Development Environment Setup** with scripts for both cloud and local environments
- **App Management** tools for creating new apps, test apps, and adding existing apps
- **Build Pipeline** using reusable workflows like `_BuildALGoProject.yaml`

The repository follows Microsoft's AL-Go framework (v7.1) for Business Central app development, providing automation for building, testing, and deploying Business Central extensions. It's designed as a template for per-tenant extensions with sample code included.

## Getting Started

To get started with this template repository, follow these steps:

1. **Clone the Repository**: Clone this repository to your local machine using `git clone https://github.com/your-repo.git`.
2. **Customize Settings**: Modify the AL-Go settings in the repository to match your project's requirements.
3. **Set Up Workflows**: Configure the GitHub Actions workflows according to your needs.
4. **Start Developing**: Begin developing your Business Central extensions using the provided templates and workflows.

## Verify-Environment Script

The `scripts\Verify-Environment.ps1` script ensures your Business Central TDD environment is properly configured and ready for use.

### Purpose

- **Verify Prerequisites**: Check if BcContainerHelper module is installed and Docker is running
- **Container Management**: Verify if the 'bctest' container exists and is running
- **Automatic Remediation**: Create the container if it doesn't exist or start it if it's stopped
- **Environment Validation**: Ensure all components are properly configured for TDD workflow

### Parameters

The script doesn't accept any parameters. It uses default values for container name ('bctest') and other settings.

### Usage Examples

Basic verification:
```powershell
.\scripts\Verify-Environment.ps1
```

Verification before running tests:
```powershell
# Check environment before running tests
if (.\scripts\Verify-Environment.ps1) {
    # Environment is ready, proceed with tests
    .\scripts\Run-Tests.ps1
}
```

### Expected Output

Successful verification:
```
SUCCESS: BcContainerHelper module is installed and imported (Version: X.X.X)
SUCCESS: Docker is running
SUCCESS: The 'bctest' container exists and is running

All environment checks passed! The environment is ready for Business Central TDD workflow.
```

Issues detected with automatic remediation:
```
The 'bctest' container does not exist. Attempting to create it...
Calling Initialize-TDDEnvironment.ps1 to create the container...
SUCCESS: The 'bctest' container has been created and started successfully
```

The script returns an exit code of 0 if all checks pass, and 1 if any check fails, making it suitable for use in automated workflows.

### Integration with TDD Workflow

- **Foundation Component**: Called by `Initialize-TDDEnvironment.ps1` during environment setup
- **Pre-Test Verification**: Use before running tests to ensure environment consistency
- **Automatic Recovery**: Recovers from common environment issues without manual intervention
- **Self-Healing**: Creates or starts the container as needed to maintain the development environment