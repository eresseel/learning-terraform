#!/bin/bash

ACTION=$1

if [ "${ACTION}" = "apply" ]; then
    echo "Applying Metallb configuration..."
    kubectl apply -f ../../modules/metallb/scripts/metallb.yml
elif [ "${ACTION}" = "delete" ]; then
    echo "Deleting Metallb configuration..."
    kubectl delete -f ../../modules/metallb/scripts/metallb.yml
else
    echo "Invalid action. Use 'apply' or 'delete'."
    exit 1
fi
