# Lambda

Lambda is a minimalist declarative package manager written in POSIX shell.

Instead of manually telling the package manager what to install and remove, Lambda uses a declared system state and reconciles the actual system with it.

## Features

- Declarative package management
- Written in POSIX shell
- JSON package recipes
- Shell commands for downloading, building, and installing packages
- Dependency definitions
- Minimal dependencies
- Designed with simplicity in mind

> Lambda is currently under development and should be considered experimental.

## How it works

Lambda uses two JSON files to represent the desired and current package states:

- `/etc/lambda/system.json` — packages the system should have
- `/var/lib/lambda/state.json` — packages currently managed by Lambda

For example:

```json
{
    "packages": [
        "vim",
        "llvm",
        "openssh"
    ]
}
````

When running:

```sh
lambda reconcile
```

Lambda compares both states and determines what needs to be installed or removed.

If the states are already synchronized:

```text
lambda: reconciling system packages...
lambda: nothing to reconcile.
```

Otherwise, Lambda shows the required changes before proceeding.

## Package recipes

Lambda packages are described using JSON files.

Example:

```json
{
    "name": "vim",
    "description": "Highly configurable text editor.",
    "version": "9.1",
    "dependencies": [
        "ncurses"
    ],
    "download": [
        "curl -fL --retry 3 --retry-delay 2 -o v9.1.0000.tar.gz https://github.com/vim/vim/archive/refs/tags/v9.1.0000.tar.gz",
        "tar -xf v9.1.0000.tar.gz"
    ],
    "build": [
        "cd vim-9.1.0000 && ./configure --prefix=\"$PREFIX\"",
        "cd vim-9.1.0000 && make $MAKEOPTS"
    ],
    "install": [
        "cd vim-9.1.0000 && make DESTDIR=\"$DESTDIR\" install"
    ]
}
```

Recipes contain:

* `name` — package name
* `description` — package description
* `version` — package version
* `dependencies` — required packages
* `download` — commands used to download and extract the source
* `build` — commands used to build the package
* `install` — commands used to install the package

### Security

**Package recipes contain executable shell commands.**

Lambda executes the commands defined in a package recipe when building and installing a package.

Because of this, **you must trust a package recipe before using it**.

Official Lambda recipes are maintained in the official package repository:

[https://github.com/kworkerr/null-packages](https://github.com/kworkerr/null-packages)

If you obtain a package recipe from a community repository or another source, inspect it carefully and make sure you trust its author before installing it.

A malicious recipe can execute arbitrary commands with the privileges used by Lambda.

## Installation

Clone Lambda:

```sh
git clone https://github.com/kworkerr/lambda-manager

cd lambda-manager
```

Clone the official package repository:

```sh
git clone https://github.com/kworkerr/null-packages
```

Copy the package recipes:

```sh
cp null-packages/packages/* packages/
```

Install Lambda:

```sh
sudo ./install.sh
```

After installation, Lambda and its package recipes will be installed into the system.

## Configuration

The desired system state is stored in:

```text
/etc/lambda/system.json
```

Lambda's current state is stored in:

```text
/var/lib/lambda/state.json
```

Lambda's package recipes are stored in:

```text
/usr/share/lambda/packages/
```

Additional Lambda components are stored in:

```text
/usr/lib/lambda/
```

The executable itself is installed to:

```text
/usr/bin/lambda
```

## Usage

Show help:

```sh
lambda --help
```

Reconcile the system:

```sh
lambda reconcile
```

Lambda will determine the differences between the desired and current states and ask for confirmation before making changes.

## Philosophy

Lambda aims to keep package management simple.

The system state should be easy to inspect, package recipes should be readable, and the package manager itself should remain small and understandable.

No giant dependency resolver.
No complicated package format.
Just JSON, shell, and a system state to reconcile.

## License

See [LICENSE](LICENSE).
