#!/bin/sh
# funcs/lambda_remove.sh

# Lambda package remover. Removes a package's files (as recorded in its
# manifest), then updates state.json and system.json.

# Args: $1 = json file, $2 = package name
_lambda_unrecord_package()
{
    _lup_file="$1"
    _lup_package="$2"

    if [ ! -f "$_lup_file" ]; then
        # Nothing recorded here at all - already effectively absent.
        return 0
    fi

    _lup_tmp=$(mktemp) || {
        echo "lambda: failed to allocate temp file for $_lup_file"
        return 1
    }

    if ! jq --arg package "$_lup_package" \
        '.packages -= [$package]' \
        "$_lup_file" > "$_lup_tmp"; then
        echo "lambda: failed to update $_lup_file"
        rm -f "$_lup_tmp"
        return 1
    fi

    install -m 644 "$_lup_tmp" "$_lup_file"
    rm -f "$_lup_tmp"
}

# Remove a single installed package: delete the files listed in its
# manifest, clean up any directories that are now empty, deletes the
# manifest itself, and remove the package from both state.json and
# system.json.

lambda_remove()
{
    _lr_package="$1"

    if [ -z "$_lr_package" ]; then
        echo "lambda: no package specified to remove."
        return 1
    fi

    _lr_manifest="/usr/share/lambda/installed/${_lr_package}.json"

    if [ ! -f "$_lr_manifest" ]; then
        echo "lambda: $_lr_package is not installed."
        return 1
    fi

    echo "lambda: removing $_lr_package..."

    _lr_filelist=$(mktemp) || {
        echo "lambda: failed to allocate file list for $_lr_package"
        return 1
    }

    if ! jq -r '.files[]' "$_lr_manifest" > "$_lr_filelist"; then
        echo "lambda: failed to read manifest for $_lr_package"
        rm -f "$_lr_filelist"
        return 1
    fi

    _lr_dirlist=$(mktemp) || {
        echo "lambda: failed to allocate directory list for $_lr_package"
        rm -f "$_lr_filelist"
        return 1
    }

    # Remove every file/symlink the manifest lists. Missing files are
    # only a warning (the filesystem may already be in the state we
    # want), but a file that exists and fails to be removed is a real
    # failure and we dont report success in this case.
    _lr_failed=0
    while IFS= read -r _lr_path; do
        [ -z "$_lr_path" ] && continue
        _lr_target="/${_lr_path#/}"
        if [ -e "$_lr_target" ] || [ -L "$_lr_target" ]; then
            if ! rm -f "$_lr_target"; then
                echo "lambda: failed to remove $_lr_target"
                _lr_failed=1
            fi
        else
            echo "lambda: warning: $_lr_target already missing, skipping"
        fi
        dirname "$_lr_target" >> "$_lr_dirlist"
    done < "$_lr_filelist"

    if [ "$_lr_failed" -ne 0 ]; then
        echo "lambda: failed to fully remove $_lr_package's files, aborting."
        rm -f "$_lr_filelist" "$_lr_dirlist"
        return 1
    fi

    # Clean up directories left behind, deepest first. A directory that's
    # still in use by another package will simply fail to rmdir (it's
    # non-empty) that's expected and is not an error, so we ignore it.
    sort -u "$_lr_dirlist" | awk '{ print length"\t"$0 }' | sort -rn | cut -f2- | \
    while IFS= read -r _lr_dir; do
        [ -z "$_lr_dir" ] && continue
        [ "$_lr_dir" = "/" ] && continue
        rmdir "$_lr_dir" 2>/dev/null
    done

    rm -f "$_lr_filelist" "$_lr_dirlist"

    if ! rm -f "$_lr_manifest"; then
        echo "lambda: failed to remove manifest for $_lr_package, aborting."
        return 1
    fi

    # The package is no longer actually installed, and no longer desired.
    if ! _lambda_unrecord_package /var/lib/lambda/state.json "$_lr_package"; then
        echo "lambda: failed to update state.json for $_lr_package"
        return 1
    fi

    if ! _lambda_unrecord_package /etc/lambda/system.json "$_lr_package"; then
        echo "lambda: failed to update system.json for $_lr_package"
        return 1
    fi

    echo "lambda: successfully removed $_lr_package!"
}
