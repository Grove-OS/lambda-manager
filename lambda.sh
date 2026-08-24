#!/bin/sh

. /usr/lib/lambda/reconcile.sh

usage()
{
    echo "Usage: lambda [OPTION]..."
    echo "Minimalist package manager"
    echo ""
    echo "--help      Displays this menu"
}

if [ "$#" -eq 0 ]; then
    usage
    exit 1
fi

if [ "$1" = "--help" ]; then
    usage
    exit 0
elif [ "$1" = "reconcile" ]; then
    reconcile
    exit 0
fi
