# Lambda

Lambda is a minimalist declarative package manager written in POSIX shell.

Instead of immediately installing or removing packages, Lambda maintains a **desired system state** and reconciles the actual system against it.

> Lambda is currently under development and should be considered experimental.

## How it works

Lambda separates **declaring changes** from **applying changes**.

The desired state is modified using `lambda mutate`, while `lambda reconcile` applies the differences to the actual system.

```text
          mutate
             │
             ▼
      desired state
             │
             │ reconcile
             ▼
       actual system
```

For example:

```sh
lambda mutate append vim
lambda mutate append llvm
lambda reconcile
```

Lambda will determine what needs to change and ask for confirmation before proceeding.

If everything is already synchronized:

```text
lambda: reconciling system packages...
lambda: nothing to reconcile.
```

## Mutating the system state

Use `lambda mutate` to modify the desired package state.

Append a package:

```sh
lambda mutate append vim
```

Purge a package:

```sh
lambda mutate purge vim
```

Multiple packages can be specified at once:

```sh
lambda mutate append vim curl openssh
```

These commands **do not immediately install or remove packages**. They only modify the desired system state.

Changes are applied with:

```sh
lambda reconcile
```

This separation makes it possible to declare several changes and apply them together.

## Package installation

Lambda uses a staging-based installation process.

Packages are first downloaded, built, and installed into a temporary filesystem tree rather than directly into `/`.

```text
download
   ↓
build
   ↓
staged installation
   ↓
commit to filesystem
   ↓
manifest
   ↓
state update
```

A typical staging directory looks like:

```text
/tmp/lambda-vim-XXXXXX/
├── work/
└── root/
    └── usr/
        ├── bin/
        └── share/
```

The `root/` directory acts as the temporary filesystem root through `DESTDIR`.

Only after the package successfully completes its build and installation steps does Lambda commit the staged files to the real filesystem.

This prevents failed builds from leaving partially installed files behind.

## Package manifests

After installing a package, Lambda records the files that were actually installed.

Manifests are stored in:

```text
/usr/share/lambda/installed/
```

For example:

```text
/usr/share/lambda/installed/vim.json
```

These manifests allow Lambda to track package ownership and provide the information required for package removal.

## Dependencies

Lambda supports package dependencies declared by package recipes.

When a package requires another package, Lambda recursively resolves and installs its dependencies before installing the requested package.

Already-installed dependencies are skipped.

The dependency chain is also recorded in the desired system state so that the complete package closure remains declarative.

## Package recipes

Lambda uses JSON package recipes containing the commands required to download, build, and install a package.

The recipes are stored locally under:

```text
/usr/share/lambda/packages/
```

The package recipe format is maintained separately in the official package repository.

Official recipes:

https://github.com/Grove-OS/packages

**Package recipes contain executable shell commands.** Always inspect and trust a recipe before installing it.

If you use recipes from a community repository or another source, make sure the source is trustworthy.

A malicious recipe can execute arbitrary commands with the privileges used by Lambda.

## Build configuration

Lambda loads the build environment from:

```text
/etc/lambda/make.conf
```

This keeps system-specific build settings separate from package recipes.

For example:

```sh
CC="clang"
CXX="clang++"

CFLAGS="-O2 -pipe -march=alderlake"
CXXFLAGS="${CFLAGS}"
LDFLAGS="-Wl,-O1"

PREFIX="/usr"

MAKEOPTS="-j6"
```

Variables such as `CC`, `CFLAGS`, `LDFLAGS`, `PREFIX`, and `MAKEOPTS` are made available to package build commands.

## Installation

Clone Lambda:

```sh
git clone https://github.com/Grove-OS/lambda-manager
cd lambda-manager
```

Clone the official package repository:

```sh
git clone https://github.com/Grove-OS/packages
```

Copy the package recipes:

```sh
cp packages/packages/* packages/
```

Install Lambda:

```sh
sudo ./install.sh
```

The installation script installs:

```text
/usr/bin/lambda
/etc/lambda/
/var/lib/lambda/
/usr/lib/lambda/
/usr/share/lambda/packages/
```

## Usage

Show help:

```sh
lambda --help
```

Modify the desired system state:

```sh
lambda mutate append <package>
lambda mutate purge <package>
```

Example:

```sh
lambda mutate append vim curl openssh
lambda mutate purge nano
```

Apply the desired state:

```sh
lambda reconcile
```

A typical workflow:

```sh
lambda mutate append vim curl openssh
lambda mutate purge nano

lambda reconcile
```

## Architecture

Lambda is intentionally small and built around a few simple components:

```text
lambda
├── command dispatch
├── mutate
├── reconcile
└── package installation
```

The system is represented through a small number of files:

```text
/etc/lambda/system.json
/var/lib/lambda/state.json
/etc/lambda/make.conf
/usr/share/lambda/packages/
/usr/share/lambda/installed/
```

The package manager itself is implemented in POSIX shell, with JSON processing handled by `jq`.

## Philosophy

Lambda aims to keep package management simple.

The desired system state should be easy to inspect, changes should be explicit, and package installation should be predictable.

No giant package manager.
No unnecessary abstraction.
No imperative installation state hidden behind commands.

Just a declared system state, package recipes, and reconciliation.

## License

See [LICENSE](LICENSE).

