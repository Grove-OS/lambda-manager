lambda_mutate()
{
    operation="$1"
    shift

    if [ -z "$operation" ] || [ "$#" -eq 0 ]; then
        echo "Usage: lambda mutate <append|purge> <package>..."
        return 1
    fi

    if [ "$(id -u)" -ne 0 ]; then
        echo "lambda: this command must be run as root."
        return 1
    fi

    case "$operation" in
        append)
            for package in "$@"; do
                package_file="/usr/share/lambda/packages/$package.json"

                if [ ! -f "$package_file" ]; then
                    echo "lambda: package '$package' not found."
                    return 1
                fi

                jq --arg package "$package" \
                    '.packages += [$package] | .packages |= unique' \
                    /etc/lambda/system.json > /tmp/lambda-system.json || {
                        echo "lambda: failed to update system state."
                        rm -f /tmp/lambda-system.json
                        return 1
                    }

                install -m 644 /tmp/lambda-system.json /etc/lambda/system.json || {
                    echo "lambda: failed to save system state."
                    rm -f /tmp/lambda-system.json
                    return 1
                }

                echo "lambda: appended '$package' to system configuration."
            done
            ;;

        purge)
            for package in "$@"; do
                jq --arg package "$package" \
                    '.packages -= [$package]' \
                    /etc/lambda/system.json > /tmp/lambda-system.json || {
                        echo "lambda: failed to update system state."
                        rm -f /tmp/lambda-system.json
                        return 1
                    }

                install -m 644 /tmp/lambda-system.json /etc/lambda/system.json || {
                    echo "lambda: failed to save system state."
                    rm -f /tmp/lambda-system.json
                    return 1
                }

                echo "lambda: purged '$package' from system configuration."
            done
            ;;

        *)
            echo "lambda: unknown mutation '$operation'."
            echo "Usage: lambda mutate <append|purge> <package>..."
            return 1
            ;;
    esac
}
