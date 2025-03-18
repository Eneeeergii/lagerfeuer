#!/bin/bash
#For testing reason: delete Operator and all dependencies
kubectl delete ns psql
kubectl delete ClusterRole postgres-operator
kubectl delete ClusterRole postgres-pod
kubectl delete ClusterRoleBinding postgres-operator
