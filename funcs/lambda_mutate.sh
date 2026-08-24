#!/bin/sh

lambda_mutate()
{
    operation="$1"
    package="$2"

    if [ -z "$operation" ] || [ -z "$package" ]; then
        echo "Usage: lambda mutate <append|purge> <package>"
        return 1
    fi

    if [ "$(id -u)" -ne 0 ]; then
        echo "lambda: this command must be run as root."
        return 1
    fi

    case "$operation" in
        append)
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

            rm -f /tmp/lambda-system.json

            echo "lambda: appended '$package' to system configuration."
            ;;

        purge)
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

            rm -f /tmp/lambda-system.json

            echo "lambda: purged '$package' from system configuration."
            ;;

        *)
            echo "lambda: unknown mutation '$operation'."
            echo "Usage: lambda mutate <append|purge> <package>"
            return 1
            ;;
    esac
}
