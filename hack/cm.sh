#!/bin/bash -x
kubectl delete configmap -nkong rolescopes
kubectl create configmap -nkong --from-file=kong/plugins/rolescopes rolescopes --dry-run=client -oyaml | kubectl apply -nkong -f -
kubectl delete po -nkong --selector=app=dataplane-kong --grace-period=0
sleep 2
kubectl wait --for=condition=ready -nkong -l app=dataplane-kong po
kubectl logs -nkong -l app=dataplane-kong -f
