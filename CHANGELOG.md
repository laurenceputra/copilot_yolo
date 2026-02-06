# Changelog

All notable changes to copilot_yolo will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1] - 2026-02-06

### Added
- **Process guard**: CI now fails if distributed runtime files change without a corresponding `VERSION` bump
- **Contributor policy**: Added `AGENTS.md` guardrails for versioning and PR description hygiene

### Fixed
- **ShellCheck compatibility**: Updated bash and zsh completion scripts to satisfy CI linting

### Changed
- **CI simplification**: Removed the Docker build test job from GitHub Actions workflow

### Documentation
- Updated technical docs to describe the release/version bump policy

## [1.1.0] - 2026-01-31

### Added (Product Perspective)
- **Health check command**: Run `copilot_yolo health` to diagnose system setup, Docker status, image status, and mounted paths
- **Better error messages**: More actionable error messages with suggestions and installation links
- **Changelog**: Comprehensive changelog following Keep a Changelog format

### Added (User Perspective)
- **Shell completions**: Automatic bash and zsh completions for commands and file paths
  - Tab completion for all copilot_yolo and copilot commands
  - File path completions for commands like `explain`, `review`, `test`, `describe`
- **Configuration file support**: Generate and use configuration files for persistent settings
  - Run `copilot_yolo config` to generate a sample config
  - Configuration file located in installation directory: `~/.copilot_yolo/.copilot_yolo.conf`
- **Improved user feedback**: Better progress indicators and status messages

### Added (Engineering Perspective)
- **CI/CD pipeline**: GitHub Actions workflow for automated testing
  - ShellCheck linting for all shell scripts
  - Docker build tests
  - Install script validation on Ubuntu and macOS
  - Health check and config generation tests
  - VERSION file format validation
- **Modular architecture**: Split functionality into separate modules
  - `.copilot_yolo_config.sh`: Configuration management
  - `.copilot_yolo_completion.bash`: Bash completions
  - `.copilot_yolo_completion.zsh`: Zsh completions
- **Improved error handling**: Centralized error handling with context and suggestions

### Changed
- Install script now downloads completion and configuration files
- Shell environment setup now automatically loads completions based on shell type
- **Auto-update mechanism now downloads all new module files** for backward compatibility
- Configuration loading now checks installation directory first
- **Removed unused logging module** to reduce complexity and confusion

### Fixed
- **Backward compatibility**: Auto-update now properly downloads new module files (config, completions)
- **Documentation**: Removed duplicate Configuration section in README
- Argument parsing converted to case statement for better maintainability
- Fixed find command with proper grouping for ownership checks

### Documentation
- Updated README with new features and commands
- Added feature summary section highlighting v1.1.0 capabilities
- Added sections for health check, shell completions, and configuration
- Improved troubleshooting section with health check recommendation
- Added comprehensive configuration documentation

## [1.0.3] - Previous Release

### Features
- Automatic version checking and updates
- Docker-based GitHub Copilot CLI
- Repository mounting and credential sharing
- Auto-rebuild on version changes

---

[1.1.1]: https://github.com/laurenceputra/copilot_yolo/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/laurenceputra/copilot_yolo/compare/v1.0.3...v1.1.0
[1.0.3]: https://github.com/laurenceputra/copilot_yolo/releases/tag/v1.0.3
