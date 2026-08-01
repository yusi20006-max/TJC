# TJC Installation Guide

This document describes how to install, configure, troubleshoot, and uninstall TJC (Termux Jules CLI) on both Linux systems and Android via Termux.

## Prerequisites

Before installing TJC, ensure that the following system dependencies are installed:

- **POSIX-compliant Shell** (`sh`/`bash`)
- **jq** (v1.6 or higher): Command-line JSON processor.
- **yq** (Python-based yq wrapper, or compatible version): Command-line YAML processor.
- **shellcheck**: Script analysis tool used for validating workflows and verifying CLI integrity.
- **curl**: For retrieving Pull Request information from GitHub.

### Installing Prerequisites

#### On Termux (Android)
```sh
pkg update
pkg install jq python-pip shellcheck curl git
pip install yq
```

#### On Debian/Ubuntu Linux
```sh
sudo apt update
sudo apt install -y jq shellcheck curl git
# Install yq using python3-pip
sudo apt install -y python3-pip python3-venv
pip3 install yq
```

#### On Arch Linux
```sh
sudo pacman -Syu jq shellcheck curl git python-pip
pip install yq
```

---

## Installation

TJC comes with an easy-to-use installer script `install.sh` in the root of the repository.

### Standard Installation
By default, TJC installs to the user's local directory (`$HOME/.local`):

1. Clone the repository and navigate to its root directory:
   ```sh
   git clone https://github.com/yusi20006-max/TJC.git
   cd TJC
   ```
2. Run the installation script:
   ```sh
   ./install.sh
   ```

The script will:
- Copy the commands, configuration templates, libraries, and docs into `$HOME/.local/share/tjc`.
- Create symlinks `tjc` and `jules` in `$HOME/.local/bin/`.

### Custom Prefix Installation
If you wish to install TJC to a custom directory, use the `--prefix` flag:

```sh
./install.sh --prefix /usr/local
```

Ensure that the `$PREFIX/bin` directory (such as `/usr/local/bin`) is in your system's `PATH`.

---

## Post-Installation Config

Ensure that your `PATH` variable includes the directory where TJC executables were installed. For a standard installation:

Add the following line to your shell profile file (e.g., `~/.bashrc`, `~/.zshrc`, or `~/.profile`):

```sh
export PATH="$HOME/.local/bin:$PATH"
```

Apply the changes immediately:
```sh
source ~/.bashrc
```

Verify the installation is successful by displaying the help menu:
```sh
tjc help
```

---

## Troubleshooting

### 1. `tjc: command not found`
- **Cause**: The installation directory is not in your shell's `PATH` variable.
- **Solution**: Confirm that `$HOME/.local/bin` is in your `PATH` by running `echo $PATH`. If missing, follow the instructions in the **Post-Installation Config** section above.

### 2. `yq: Error running jq: ParserError...`
- **Cause**: Some systems have a Go-based `yq` or an incompatible alias. TJC relies on the Python-based `yq` wrapper which translates YAML to JSON and forwards it to `jq`.
- **Solution**: Ensure the Python-based `yq` is installed and takes precedence in your `PATH`. Verify with `yq --version` (which should display `yq 0.0.0` or mention the python/kislyuk implementation).

### 3. Permission Denied when Running Installer
- **Cause**: The `install.sh` script does not have execute permissions.
- **Solution**: Grant execution permission using `chmod`:
  ```sh
  chmod +x install.sh
  ./install.sh
  ```

---

## Uninstallation

To remove TJC and all its symbolic links, run the `uninstall.sh` script from the repository:

```sh
./uninstall.sh
```

If you installed TJC to a custom prefix, pass the same prefix during uninstallation:

```sh
./uninstall.sh --prefix /usr/local
```
