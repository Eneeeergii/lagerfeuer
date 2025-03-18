#!/bin/bash
#For testing reason: delete Operator and all dependencies
kubectl delete ns psql
kubectl delete ClusterRole postgres-operator
kubectl delete ClusterRole postgres-pod
kubectl delete ClusterRoleBinding postgres-operator
kubectl delete customresourcedefinition postgresqls.acid.zalan.do
kubectl delete customresourcedefinition postgresteams.acid.zalan.do
