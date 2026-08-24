. /usr/lib/lambda/lambda_install.sh
. /usr/lib/lambda/lambda_remove.sh

reconcile()
{
    system_packages=$(jq -c '.packages' /etc/lambda/system.json)
    state_packages=$(jq -c '.packages' /var/lib/lambda/state.json)

    echo "lambda: reconciling system packages..."
    if [ "$system_packages" = "$state_packages" ]; then
        echo "lambda: nothing to reconcile."
        return 0
    fi

    if [ "$(id -u)" -ne 0 ]; then
        echo "lambda: this command must be run as root."
        exit 1
    fi

    install_packages=$(jq -n -r \
        --slurpfile system /etc/lambda/system.json \
        --slurpfile state /var/lib/lambda/state.json \
        '$system[0].packages - $state[0].packages | .[]')

    remove_packages=$(jq -n -r \
        --slurpfile system /etc/lambda/system.json \
        --slurpfile state /var/lib/lambda/state.json \
        '$state[0].packages - $system[0].packages | .[]')

    for package in $install_packages; do
        echo "lambda: package $package needs to be installed."
    done

    for package in $remove_packages; do
        echo "lambda: package $package needs to be removed."
    done

    printf "Do you want to proceed to reconcile your system? [y/N] "
    read answer

    case "$answer" in
        y|Y|yes|YES)
            echo "lambda: proceeding with reconciliation..."
            ;;
        *)
            echo "lambda: reconciliation cancelled."
            return 0
            ;;
    esac

    for package in $install_packages; do
        lambda_install $package
    done

    for package in $remove_packages; do
        lambda_remove $package
    done


}
