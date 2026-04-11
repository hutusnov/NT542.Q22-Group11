#!/bin/bash

echo "==== 4.1.1 Check cluster-admin usage ===="

kubectl get clusterrolebinding -o jsonpath='{range .items[?(@.roleRef.name=="cluster-admin")]}{.metadata.name}{"\n"}{range .subjects[*]}{.kind}{"\t"}{.name}{"\n"}{end}{"\n"}{end}'