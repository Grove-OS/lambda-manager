#!/bin/sh

. /usr/lib/lambda/lambda_reconcile.sh
. /usr/lib/lambda/lambda_mutate.sh

usage()
{
    echo "Usage: lambda <command> [arguments]..."
    echo "Minimalist declarative package manager"
    echo ""
    echo "Commands:"
    echo "  mutate <append|purge> <package>"
    echo "      Modify the desired system state."
    echo ""
    echo "  reconcile"
    echo "      Reconcile the system with the desired state."
    echo ""
    echo "  --help"
    echo "      Display this help message."
}

if [ "$#" -eq 0 ]; then
    usage
    exit 1
fi

if [ "$1" = "--help" ]; then
    usage
    exit 0
elif [ "$1" = "reconcile" ]; then
    lambda_reconcile
    exit $?
elif [ "$1" = "mutate" ]; then
    lambda_mutate "$2" "$3"
    exit $?
fi
