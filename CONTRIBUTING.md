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
chmod +x copilot_yolo.sh
```

3. Make your changes to:
   - `copilot_yolo.sh` - Main bash script
   - `Dockerfile` - Docker image definition
   - `entrypoint.sh` - Container entrypoint script
   - `README.md` - Documentation

4. Test your changes:
```bash
# Test the script
./copilot_yolo.sh --help

# Test with a sample project
mkdir -p /tmp/test-project
cd /tmp/test-project
echo "print('hello')" > test.py
/path/to/copilot_yolo/copilot_yolo.sh
```

## Rebuilding the Docker Image

After making changes to the Dockerfile or entrypoint script:

```bash
./copilot_yolo.sh --rebuild
```

## Code Style

### Bash Scripts
- Follow the Google Shell Style Guide
- Use `shellcheck` to lint bash scripts
- Add comments for complex logic
- Use meaningful variable names
- Quote variables to prevent word splitting

### Docker Files
- Keep layers minimal
- Clean up after installing packages
- Use specific versions where possible

## Testing

Before submitting a PR, test:

1. Fresh Docker build: `./copilot_yolo.sh --rebuild`
2. Running in different directories
3. Help output: `./copilot_yolo.sh --help`
4. Edge cases (non-existent directory, no Docker, etc.)

## Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Questions?

Feel free to open an issue for any questions or concerns.
