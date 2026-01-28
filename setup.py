#!/usr/bin/env python3
"""Setup script for copilot_yolo."""

from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="copilot_yolo",
    version="0.1.0",
    author="Laurence Putra Franslay",
    description="A command-line tool that runs GitHub Copilot CLI in Docker with Yolo mode",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/laurenceputra/copilot_yolo",
    packages=find_packages(),
    package_data={
        "copilot_yolo": ["Dockerfile", "entrypoint.sh"],
    },
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: POSIX :: Linux",
        "Operating System :: MacOS :: MacOS X",
        "Environment :: Console",
        "Intended Audience :: Developers",
        "Topic :: Software Development :: Tools",
    ],
    python_requires=">=3.6",
    entry_points={
        "console_scripts": [
            "copilot_yolo=copilot_yolo.cli:main",
        ],
    },
    install_requires=[],
)
