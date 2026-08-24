#!/bin/sh
# funcs/lambda_install.sh
#
# Lambda package installer with staged (fakeroot-style) installation.

_lambda_run_section()
{
    _lrs_package_file="$1"
    _lrs_section="$2"
    _lrs_workdir="$3"

    while IFS= read -r _lrs_command; do
        [ -z "$_lrs_command" ] && continue
        echo "lambda: $_lrs_command"
        ( cd "$_lrs_workdir" && sh -c "$_lrs_command" )
        if [ $? -ne 0 ]; then
            return 1
        fi
    done <<EOF
$(jq -r ".${_lrs_section}[]" "$_lrs_package_file")
EOF

    return 0
}

lambda_install()
{
    package="$1"
    package_file="/usr/share/lambda/packages/$package.json"

    if [ ! -f "$package_file" ]; then
        echo "lambda: package '$package' not found."
        return 1
    fi

    # Load build environment. CXXFLAGS etc. depend on CFLAGS being defined
    # first, so we just source the file in instead parsing it.
    if [ -f /etc/lambda/make.conf ]; then
        . /etc/lambda/make.conf
    else
        echo "lambda: /etc/lambda/make.conf not found."
        return 1
    fi

    version=$(jq -r '.version' "$package_file")

    staging=$(mktemp -d "/tmp/lambda-${package}-XXXXXX") || {
        echo "lambda: failed to create staging directory for $package"
        return 1
    }
    workdir="$staging/work"
    destdir="$staging/root"
    mkdir -p "$workdir" "$destdir" || {
        echo "lambda: failed to set up staging directory for $package"
        rm -rf "$staging"
        return 1
    }

    # DESTDIR is what package recipes install into ('make DESTDIR="$DESTDIR" install').
    # PREFIX still represents the final install location, recipes combine
    # DESTDIR + PREFIX.
    DESTDIR="$destdir"
    export DESTDIR CC CXX CFLAGS CXXFLAGS LDFLAGS PREFIX MAKEOPTS XORG_PREFIX XORG_CONFIG

    # Cleanup if we get interrupted mid-install.
    trap 'rm -rf "$staging"' INT TERM

    echo "lambda: installing $package..."

    echo "lambda: downloading $package..."
    if ! _lambda_run_section "$package_file" download "$workdir"; then
        echo "lambda: download failed for $package, aborting."
        rm -rf "$staging"
        trap - INT TERM
        return 1
    fi

    echo "lambda: building $package..."
    if ! _lambda_run_section "$package_file" build "$workdir"; then
        echo "lambda: build failed for $package, aborting."
        rm -rf "$staging"
        trap - INT TERM
        return 1
    fi

    echo "lambda: installing $package..."
    if ! _lambda_run_section "$package_file" install "$workdir"; then
        echo "lambda: install failed for $package, aborting."
        rm -rf "$staging"
        trap - INT TERM
        return 1
    fi

    # Everything succeeded, commit the staged tree into the real filesystem.
    echo "lambda: committing $package to filesystem..."

    filelist=$(mktemp) || {
        echo "lambda: failed to allocate file list for $package"
        rm -rf "$staging"
        trap - INT TERM
        return 1
    }

    ( cd "$destdir" && find . -mindepth 1 \( -type f -o -type l \) ) \
        | sed 's|^\.||' > "$filelist"

    if [ ! -s "$filelist" ]; then
        echo "lambda: warning: $package staged no files"
    fi

    # Use tar to copy staged files onto / so permissions, ownership (where
    # possible) and symlinks are preserved, rather than plain cp -r.
    if ! ( cd "$destdir" && tar -cf - . ) | ( cd / && tar -xpf - ); then
        echo "lambda: failed to commit staged files for $package"
        rm -rf "$staging" "$filelist"
        trap - INT TERM
        return 1
    fi

    # Write the package manifest from what was actually staged, not from
    # the recipe.
    mkdir -p /usr/share/lambda/installed || {
        echo "lambda: failed to create manifest directory"
        rm -rf "$staging" "$filelist"
        trap - INT TERM
        return 1
    }

    manifest="/usr/share/lambda/installed/${package}.json"
    files_json=$(jq -R -s 'split("\n") | map(select(length > 0))' "$filelist")
    jq -n \
        --arg name "$package" \
        --arg version "$version" \
        --argjson files "$files_json" \
        '{name: $name, version: $version, files: $files}' > "$manifest"

    jq --arg package "$package" \
        '.packages += [$package] | .packages |= unique' \
        /var/lib/lambda/state.json > /tmp/lambda-state.json || {
            echo "lambda: failed to update system state"
            rm -rf "$staging" "$filelist"
            trap - INT TERM
            return 1
        }

    install -m 644 /tmp/lambda-state.json /var/lib/lambda/state.json
    rm -f /tmp/lambda-state.json

    rm -rf "$staging" "$filelist"
    trap - INT TERM

    echo "lambda: successfully installed $package!"
}
