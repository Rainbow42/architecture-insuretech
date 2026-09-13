# Доказательства проверки

- `memory-hpa.log` показывает увеличение Deployment с одной до двух реплик при превышении целевой утилизации памяти 80%.
- `prometheus-rps.png` показывает сбор `http_requests_total` и вычисление RPS по pod в Prometheus.
- `rps-hpa.log` показывает доступность custom metric и увеличение Deployment с одной до пяти, затем до десяти реплик.

Официальный образ `ghcr.io/yandex-practicum/scaletestapp:latest` на момент проверки не содержал manifest для `linux/arm64/v8`. Поэтому только в локальном испытательном кластере образ был подменён на небольшой arm64-совместимый HTTP-сервис с теми же endpoint `/` и `/metrics` и метрикой `http_requests_total`. Сдаваемый `deployment.yaml` использует требуемый образ Практикума без изменений.
