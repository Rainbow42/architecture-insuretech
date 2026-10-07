#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

profile=${1:-sprint8-check}
minikube -p "$profile" status >/dev/null
minikube -p "$profile" addons enable metrics-server
kubectl --context "$profile" create namespace sprint8 --dry-run=client -o yaml |
  kubectl --context "$profile" apply -f -
kubectl --context "$profile" -n sprint8 apply -f deployment.yaml -f service.yaml
kubectl --context "$profile" -n sprint8 rollout status deployment/scaletestapp --timeout=180s

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update prometheus-community
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --version 90.0.0 --kube-context "$profile" -n monitoring --create-namespace \
  --set alertmanager.enabled=false --set grafana.enabled=false \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --wait --timeout 5m
kubectl --context "$profile" -n sprint8 apply -f service-monitor.yaml
helm upgrade --install prometheus-adapter prometheus-community/prometheus-adapter \
  --version 5.3.0 --kube-context "$profile" -n monitoring \
  --set prometheus.url=http://prometheus-kube-prometheus-prometheus.monitoring.svc \
  --set prometheus.port=9090 -f prometheus-adapter-values.yaml \
  --wait --timeout 5m
kubectl --context "$profile" -n sprint8 create configmap scaletestapp-locust \
  --from-file=locustfile.py --dry-run=client -o yaml |
  kubectl --context "$profile" -n sprint8 apply -f -
