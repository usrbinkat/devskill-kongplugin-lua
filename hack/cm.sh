#!/bin/bash -x
kubectl create configmap -nkong --from-file=kong/plugins/myplugin myplugin --dry-run=client -oyaml | kubectl apply -nkong -f -
