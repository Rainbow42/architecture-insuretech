#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
profile=${1:-sprint8-check}
minikube -p "$profile" status >/dev/null
mkdir -p evidence
stamp=$(date -u +%Y%m%dT%H%M%SZ)
exec > >(tee "evidence/rate-limit-${stamp}.log") 2>&1
printf 'Started UTC: %s\nContext: %s\n' "$stamp" "$profile"

remote() { minikube -p "$profile" ssh -- "$1"; }
remote 'sudo docker pull -q nginx:1.29.1-alpine'
remote 'sudo docker network create sprint8-nginx-test'
cleanup() {
  remote 'sudo docker rm -f sprint8-nginx-proxy sprint8-nginx-backend; sudo docker network rm sprint8-nginx-test; sudo rm -f /tmp/sprint8-nginx.conf' || true
}
trap cleanup EXIT
minikube -p "$profile" cp nginx.conf /tmp/sprint8-nginx.conf
remote 'sudo docker run -d --name sprint8-nginx-backend --network sprint8-nginx-test --network-alias backend1.example.com --network-alias backend2.example.com --network-alias backend3.example.com nginx:1.29.1-alpine'
remote 'sudo docker run --rm --network sprint8-nginx-test -v /tmp/sprint8-nginx.conf:/etc/nginx/nginx.conf:ro nginx:1.29.1-alpine nginx -t'
remote 'sudo docker run -d --name sprint8-nginx-proxy --network sprint8-nginx-test -p 18080:80 -v /tmp/sprint8-nginx.conf:/etc/nginx/nginx.conf:ro nginx:1.29.1-alpine'
sleep 2
python3 test_rate_limit.py "http://$(minikube -p "$profile" ip):18080/"
