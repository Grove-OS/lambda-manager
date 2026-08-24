#!/bin/sh

lambda_installer()
{
    echo "Creating /etc/lambda/ ..."
    mkdir -pv /etc/lambda/ || return 1

    echo "Installing config/system.json to /etc/lambda/ ..."
    install -m 644 config/system.json /etc/lambda/system.json || return 1

    echo "Installing config/make.conf to /etc/lambda/ ..."
    install -m 644 config/make.conf /etc/lambda/make.conf || return 1

    echo "Creating /var/lib/lambda/ ..."
    mkdir -pv /var/lib/lambda/ || return 1

    echo "Installing config/state.json to /var/lib/lambda/ ..."
    install -m 644 config/state.json /var/lib/lambda/state.json || return 1

    echo "Creating /usr/lib/lambda/ ..."
    mkdir -pv /usr/lib/lambda/ || return 1

    echo "Installing funcs/reconcile.sh to /usr/lib/lambda/ ..."
    install -m 644 funcs/reconcile.sh /usr/lib/lambda/reconcile.sh || return 1

    echo "Installing funcs/lambda_install.sh to /usr/lib/lambda/ ..."
    install -m 644 funcs/lambda_install.sh /usr/lib/lambda/lambda_install.sh || return 1

    echo "Installing funcs/lambda_remove.sh to /usr/lib/lambda/ ..."
    install -m 644 funcs/lambda_remove.sh /usr/lib/lambda/lambda_remove.sh || return 1

    echo "Creating /usr/share/lambda/packages/ ..."
    mkdir -pv /usr/share/lambda/packages/ || return 1

    echo "Installing package repository..."
    cp -r packages/. /usr/share/lambda/packages/ || return 1

    echo "Installing lambda..."
    install -m 755 lambda.sh /usr/bin/lambda || return 1

    echo "Successfully installed lambda!"
}

if [ "$(id -u)" -ne 0 ]; then
    echo "install.sh: this script must be run as root."
    exit 1
fi

lambda_installer || exit 1
