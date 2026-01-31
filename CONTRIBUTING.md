# Contributing to copilot_yolo

Thank you for your interest in contributing to copilot_yolo!

## Development Setup

1. Clone the repository:
```bash
git clone https://github.com/laurenceputra/copilot_yolo.git
cd copilot_yolo
```

2. Make the script executable:
```bash
chmod +x .copilot_yolo.sh
```

3. Make your changes to:
   - `.copilot_yolo.sh` - Main bash script
   - `.copilot_yolo.Dockerfile` - Docker image definition
   - `.copilot_yolo_entrypoint.sh` - Container entrypoint script
   - `.copilot_yolo_config.sh` - Configuration module
   - `.copilot_yolo_logging.sh` - Logging module
   - `.copilot_yolo_completion.bash` / `.copilot_yolo_completion.zsh` - Shell completions
   - `README.md` - User documentation
   - `TECHNICAL.md` - Technical documentation

4. Test your changes:
```bash
# Test the script
COPILOT_SKIP_UPDATE_CHECK=1 ./.copilot_yolo.sh --help

# Test health check
COPILOT_SKIP_UPDATE_CHECK=1 ./.copilot_yolo.sh health

# Test with a sample project
mkdir -p /tmp/test-project
cd /tmp/test-project
echo "print('hello')" > test.py
COPILOT_SKIP_UPDATE_CHECK=1 /path/to/copilot_yolo/.copilot_yolo.sh
```

## Architecture

See [TECHNICAL.md](TECHNICAL.md) for detailed architecture documentation including:
- Module structure and responsibilities
- Auto-update mechanism design
- Configuration system
- Error handling patterns
- Testing approach

## Rebuilding the Docker Image

After making changes to the Dockerfile or entrypoint script:

```bash
./.copilot_yolo.sh --pull
# or
COPILOT_BUILD_NO_CACHE=1 ./.copilot_yolo.sh
```

## Code Style

### Bash Scripts
- Follow the Google Shell Style Guide
- Use `shellcheck` to lint bash scripts
- Add comments for complex logic
- Use meaningful variable names
- Quote variables to prevent word splitting: `"${VAR}"`
- Use `[[ ]]` for tests, not `[ ]`
- Use `$(command)` not backticks

### Docker Files
- Keep layers minimal
- Clean up after installing packages
- Use specific versions where possible

## Testing

Before submitting a PR, test:

1. Shell syntax: `bash -n .copilot_yolo.sh`
2. ShellCheck: `shellcheck .copilot_yolo.sh`
3. Fresh Docker build: `COPILOT_BUILD_NO_CACHE=1 ./.copilot_yolo.sh`
4. Health check: `./.copilot_yolo.sh health`
5. Config generation: `./.copilot_yolo.sh config /tmp/test.conf`
6. Running in different directories
7. Help output: `./.copilot_yolo.sh --help`

See `.github/workflows/ci.yml` for automated tests that run on every PR.

## Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Update CHANGELOG.md with your changes
5. Update TECHNICAL.md if you changed architecture
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Documentation

When adding features:
- Update README.md with user-facing changes
- Update TECHNICAL.md with technical details
- Update CHANGELOG.md following Keep a Changelog format
- Add code comments for complex logic

## Questions?

Feel free to open an issue for any questions or concerns.

