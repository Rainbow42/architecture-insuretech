# Динамическое масштабирование

## Часть 1 — память

```bash
minikube start
minikube addons enable metrics-server
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f hpa-memory.yaml
kubectl port-forward service/scaletestapp 8080:8080
locust -f locustfile.py --host http://localhost:8080
kubectl get hpa,pods -w
```

HPA поддерживает среднюю утилизацию памяти на уровне 80% от `requests.memory`. Максимум — 10 реплик. Перед частью 2 удалите первый HPA: `kubectl delete -f hpa-memory.yaml`.

## Часть 2 — RPS

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack
kubectl apply -f service-monitor.yaml
helm upgrade --install prometheus-adapter prometheus-community/prometheus-adapter \
  --set prometheus.url=http://prometheus-kube-prometheus-prometheus.default.svc \
  --set prometheus.port=9090 \
  -f prometheus-adapter-values.yaml
kubectl apply -f hpa-rps.yaml
kubectl get --raw /apis/custom.metrics.k8s.io/v1beta1
kubectl get hpa,pods -w
```

Для проверки метрики `http_requests_total` откройте Prometheus:

```bash
kubectl port-forward service/prometheus-kube-prometheus-prometheus 9090:9090
```

Запрос в Prometheus: `sum(rate(http_requests_total[1m])) by (pod)`. HPA создаёт новую реплику, когда средний RPS на pod превышает 10.

Доказательства запусков размещаются в `evidence/`: снимок Prometheus и логи изменения числа реплик для обоих вариантов HPA.
