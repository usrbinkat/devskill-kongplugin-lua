#!/bin/bash -x
kubectl delete configmap -nkong rolescopes
kubectl create configmap -nkong --from-file=kong/plugins/rolescopes rolescopes --dry-run=client -oyaml | kubectl apply -nkong -f -
