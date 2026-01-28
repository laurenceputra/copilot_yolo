# Contributing to copilot_yolo

Thank you for your interest in contributing to copilot_yolo!

## Development Setup

1. Clone the repository:
```bash
git clone https://github.com/laurenceputra/copilot_yolo.git
cd copilot_yolo
```

2. Install in development mode:
```bash
pip install -e .
```

3. Make your changes

4. Test your changes:
```bash
# Test the CLI
copilot_yolo --help

# Test with a sample project
mkdir -p /tmp/test-project
cd /tmp/test-project
echo "print('hello')" > test.py
copilot_yolo
```

## Rebuilding the Docker Image

After making changes to the Dockerfile or entrypoint script:

```bash
copilot_yolo --rebuild
```

## Code Style

- Follow PEP 8 for Python code
- Use meaningful variable and function names
- Add docstrings to functions
- Keep functions focused and small

## Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Questions?

Feel free to open an issue for any questions or concerns.
