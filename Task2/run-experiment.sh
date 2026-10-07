#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

mode=${1:?Usage: bash run-experiment.sh memory|rps [minikube-profile]}
profile=${2:-sprint8-check}
case "$mode" in memory|rps) ;; *) exit 2 ;; esac
minikube -p "$profile" status >/dev/null
k=(kubectl --context "$profile" -n sprint8)
mkdir -p evidence
stamp=$(date -u +%Y%m%dT%H%M%SZ)
exec > >(tee "evidence/${mode}-${stamp}.log") 2>&1
printf 'Started UTC: %s\nMode: %s\nContext: %s\n' "$stamp" "$mode" "$profile"
"${k[@]}" get nodes -o wide
"${k[@]}" delete job scaletestapp-load --ignore-not-found --wait=true --timeout=180s
"${k[@]}" delete hpa scaletestapp-memory scaletestapp-rps --ignore-not-found
"${k[@]}" scale deployment/scaletestapp --replicas=1
"${k[@]}" rollout restart deployment/scaletestapp
"${k[@]}" rollout status deployment/scaletestapp --timeout=180s
"${k[@]}" get deployment scaletestapp -o yaml
"${k[@]}" get pods -l app=scaletestapp -o wide
baseline_pod=$("${k[@]}" get pods -l app=scaletestapp --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')
metrics_ready=false
for ((attempt=0; attempt<12; attempt++)); do
  if "${k[@]}" top pod "$baseline_pod"; then
    metrics_ready=true
    break
  fi
  sleep 10
done
if [ "$metrics_ready" != true ]; then
  printf 'metrics-server did not return the baseline within 120s\n' >&2
  exit 1
fi
"${k[@]}" apply -f "hpa-${mode}.yaml"
"${k[@]}" apply -f locust-job.yaml
"${k[@]}" wait --for=condition=Ready pod -l job-name=scaletestapp-load --timeout=180s

for ((sample=0; sample<36; sample++)); do
  date -u '+%Y-%m-%dT%H:%M:%SZ'
  "${k[@]}" get hpa "scaletestapp-${mode}"
  "${k[@]}" get deployment scaletestapp
  "${k[@]}" top pods -l app=scaletestapp || true
  sleep 10
done

"${k[@]}" logs job/scaletestapp-load
"${k[@]}" get job scaletestapp-load -o yaml
"${k[@]}" describe hpa "scaletestapp-${mode}"
"${k[@]}" get pods -l app=scaletestapp -o wide
"${k[@]}" get pods -l app=scaletestapp -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.containerStatuses[0].imageID}{" restarts="}{.status.containerStatuses[0].restartCount}{"\n"}{end}'
"${k[@]}" get events --field-selector involvedObject.kind=HorizontalPodAutoscaler --sort-by=.metadata.creationTimestamp
if [ "$mode" = rps ]; then
  "${k[@]}" get --raw '/apis/custom.metrics.k8s.io/v1beta1/namespaces/sprint8/pods/*/http_requests_per_second'
fi
"${k[@]}" wait --for=condition=Complete job/scaletestapp-load --timeout=30s
printf '\nFinished UTC: %s\n' "$(date -u +%Y%m%dT%H%M%SZ)"
