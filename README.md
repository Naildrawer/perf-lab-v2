# Java Performance Demo

Учебный production-like проект для практики в **performance engineering**, мониторинге, Kubernetes, Ansible, Terraform и CI/CD.

Проект показывает, как одно Java-приложение можно запускать в двух режимах:

- локально через **Docker Compose**;
- в Kubernetes через **k3s**.

Вокруг приложения собран полный observability-стенд: **Prometheus, Grafana, exporters, cAdvisor, node-exporter**, а инфраструктурная часть описана через **Kubernetes manifests, Ansible и Terraform cloud-ready слой**.

---

## Цель проекта

Цель проекта — не просто запустить Spring Boot приложение, а собрать воспроизводимый стенд, который можно использовать для демонстрации навыков:

- контейнеризации;
- Kubernetes manifests;
- мониторинга Java-приложения;
- сбора JVM, HTTP, PostgreSQL, Redis, container и node metrics;
- persistence через PVC;
- provisioning Grafana и Prometheus через ConfigMap;
- автоматизации через Ansible;
- cloud-ready Infrastructure as Code через Terraform;
- базового GitLab CI pipeline.

---

## Стек

### Application

- Java 17
- Spring Boot
- Spring Web
- Spring Data JDBC
- Spring Cache
- Redis
- PostgreSQL
- Spring Actuator
- Micrometer Prometheus Registry

### Infrastructure

- Docker
- Docker Compose
- Nginx
- Kubernetes / k3s
- Ansible
- Terraform

### Monitoring

- Prometheus
- Grafana
- postgres-exporter
- redis-exporter
- node-exporter
- cAdvisor
- kubelet cAdvisor metrics

### CI/CD

- GitLab CI
- Terraform format/validate
- Kubernetes manifests validation
- Ansible syntax check
- Maven build
- Docker build
- Docker Compose config validation

---

## Архитектура

### Docker Compose режим

```text
Client
  -> Nginx :80
      -> Spring Boot app #1
      -> Spring Boot app #2
          -> PostgreSQL
          -> Redis

Prometheus
  -> Spring Boot /actuator/prometheus
  -> PostgreSQL exporter
  -> Redis exporter
  -> node-exporter
  -> cAdvisor

Grafana
  -> Prometheus
```

### Kubernetes/k3s режим

```text
Client
  -> NodePort :30080
      -> Service app
          -> Spring Boot pods
              -> PostgreSQL Service
              -> Redis Service

Prometheus
  -> Kubernetes pod discovery
  -> Spring Boot /actuator/prometheus
  -> PostgreSQL exporter
  -> Redis exporter
  -> node-exporter
  -> cAdvisor
  -> kubelet cAdvisor metrics

Grafana
  -> Prometheus datasource
  -> provisioned dashboards
```

---

## Основные endpoint'ы

### Docker Compose

| Сервис | URL |
|---|---|
| Application | `http://localhost/users` |
| Grafana | `http://localhost:3000` |
| Prometheus | `http://localhost:9090` |

### Kubernetes/k3s

| Сервис | URL |
|---|---|
| Application | `http://localhost:30080/users` |
| Grafana | `http://localhost:30030` |
| Prometheus | `http://localhost:30090` |

Grafana credentials для lab:

```text
login: admin
password: admin
```

---

## Структура проекта

```text
.
├── app/                         # Spring Boot приложение
├── ansible/                     # Ansible playbooks
├── docker-compose.yml           # Docker Compose стенд
├── grafana/
│   ├── dashboards/              # JSON dashboards
│   └── provisioning/            # Datasource и dashboard provider для Docker Compose
├── k8s/                         # Kubernetes manifests
├── nginx/                       # Nginx config
├── postgres/                    # init.sql
├── prometheus/                  # Prometheus configs для Docker/Kubernetes
├── terraform/                   # Cloud-ready Terraform слой
└── .gitlab-ci.yml               # GitLab CI pipeline
```

---

## Быстрый запуск через Ansible

### Установить Docker

```bash
cd ~/training/java-performance-demo/ansible

ansible-playbook playbooks/install-docker.yml
```

### Установить k3s

```bash
cd ~/training/java-performance-demo/ansible

ansible-playbook playbooks/install-k3s.yml
```

---

## Docker Compose режим

Запуск:

```bash
cd ~/training/java-performance-demo/ansible

ansible-playbook playbooks/docker-up.yml
```

Что делает playbook:

- останавливает k3s;
- выполняет `k3s-killall.sh`, чтобы убрать оставшиеся pod-процессы и освободить порты;
- запускает Docker Compose;
- проверяет доступность application, Prometheus и Grafana.

Проверка вручную:

```bash
curl http://localhost/users
curl http://localhost:9090/-/ready
curl -I http://localhost:3000
```

Остановка:

```bash
cd ~/training/java-performance-demo/ansible

ansible-playbook playbooks/docker-down.yml
```

---

## Kubernetes/k3s режим

Запуск:

```bash
cd ~/training/java-performance-demo/ansible

ansible-playbook playbooks/k8s-up.yml
```

Что делает playbook:

- останавливает Docker Compose;
- запускает k3s;
- применяет Kubernetes manifests из `k8s/`;
- ждёт rollout основных компонентов;
- проверяет pod'ы, service'ы и PVC;
- проверяет доступность application, Prometheus и Grafana.

Проверка вручную:

```bash
kubectl get pods -n perf-lab
kubectl get svc -n perf-lab
kubectl get pvc -n perf-lab

curl http://localhost:30080/users
curl http://localhost:30090/-/ready
curl -I http://localhost:30030
```

Остановка k3s-режима:

```bash
cd ~/training/java-performance-demo/ansible

ansible-playbook playbooks/k8s-down.yml
```

---

## Kubernetes manifests

В папке `k8s/` описаны:

- `namespace.yaml`
- `app.yaml`
- `postgres.yaml`
- `redis.yaml`
- `postgres-exporter.yaml`
- `redis-exporter.yaml`
- `node-exporter.yaml`
- `cadvisor.yaml`
- `prometheus-rbac-service-view.yaml`
- `prometheus-config.yaml`
- `prometheus.yaml`
- `grafana-datasources.yaml`
- `grafana-dashboard-providers.yaml`
- `grafana-dashboards.yaml`
- `grafana.yaml`
- `ingress.yaml`

Prometheus и Grafana не настраиваются руками после запуска. Их конфигурация описана как Kubernetes manifests:

```text
Prometheus config     -> ConfigMap
Grafana datasource    -> ConfigMap
Grafana dashboards    -> ConfigMap
Grafana runtime data  -> PVC
Prometheus TSDB       -> PVC
PostgreSQL data       -> PVC
```

---

## Grafana provisioning

Grafana dashboards и datasource воспроизводятся из Git.

В Kubernetes используются:

```text
k8s/grafana-datasources.yaml
k8s/grafana-dashboard-providers.yaml
k8s/grafana-dashboards.yaml
k8s/grafana.yaml
```

Это значит, что после развёртывания на новой VM Grafana автоматически получает:

- Prometheus datasource;
- dashboard provider;
- dashboards из JSON.

Важно: ручные изменения, сделанные в UI Grafana, не являются source of truth. Если dashboard изменён руками, его нужно экспортировать в JSON и сохранить в репозитории.

---

## Prometheus

В Docker Compose Prometheus использует:

```text
prometheus/prometheus.yml
```

В Kubernetes Prometheus использует:

```text
k8s/prometheus-config.yaml
```

Prometheus в Kubernetes хранит TSDB в PVC:

```text
prometheus-pvc -> /prometheus
```

Это позволяет переживать restart pod'а, restart k3s и reboot VM при сохранении локального диска.

---

## Persistence

В текущем lab-стенде используются PVC на local-path storage k3s.

Данные переживают:

- restart pod'а;
- restart k3s;
- reboot VM.

Но если VM или её диск удалены, local-path данные будут потеряны.

Production-like развитие:

```text
PostgreSQL live data  -> cloud disk / network storage
Prometheus TSDB       -> cloud disk / network storage
Grafana runtime data  -> cloud disk / network storage
```

S3/Object Storage не используется как live-volume для PostgreSQL или Prometheus.

S3/Object Storage можно добавить позже для:

- PostgreSQL backups;
- long-term metrics через Thanos / Mimir / VictoriaMetrics;
- artifact storage.

---

## Terraform

Terraform-слой находится в папке:

```text
terraform/
```

Он добавлен как cloud-ready часть проекта.

Terraform отвечает за будущую подготовку инфраструктуры в Yandex Cloud:

- VPC network;
- subnet;
- security group;
- virtual machine;
- boot disk;
- public IP;
- SSH access.

Terraform не разворачивает Kubernetes manifests. Он готовит инфраструктуру, а Ansible уже настраивает VM и запускает стенд.

Проверка форматирования:

```bash
cd ~/training/java-performance-demo

terraform fmt -recursive
```

Если Terraform Registry недоступен из-за geo-block, можно использовать provider mirror Yandex Cloud через `~/.terraformrc`:

```hcl
provider_installation {
  network_mirror {
    url     = "https://terraform-mirror.yandexcloud.net/"
    include = ["registry.terraform.io/*/*"]
  }

  direct {
    exclude = ["registry.terraform.io/*/*"]
  }
}
```

После этого:

```bash
cd ~/training/java-performance-demo/terraform/environments/yandex

rm -rf .terraform .terraform.lock.hcl
terraform init -upgrade
terraform validate
```

Подробнее см. `terraform/README.md`.

---

## GitLab CI

В проект добавлен `.gitlab-ci.yml`.

Pipeline выполняет:

- `terraform fmt`;
- `terraform init` / `terraform validate`;
- Kubernetes manifests dry-run validation;
- Ansible playbooks syntax check;
- Spring Boot Maven build;
- Docker image build;
- Docker Compose config validation.

Pipeline ничего не деплоит автоматически и не меняет состояние VM. Это безопасный CI-слой для проверки проекта.

---

## Полезные команды

### Docker

```bash
docker ps
docker compose ps
docker compose logs -f
docker compose down
```

### Kubernetes

```bash
kubectl get pods -n perf-lab
kubectl get svc -n perf-lab
kubectl get pvc -n perf-lab
kubectl get configmap -n perf-lab

kubectl logs -n perf-lab deployment/app
kubectl logs -n perf-lab deployment/prometheus
kubectl logs -n perf-lab deployment/grafana
```

### Проверка Grafana ConfigMaps

```bash
kubectl get cm -n perf-lab | grep grafana
kubectl exec -n perf-lab deployment/grafana -- ls -lah /var/lib/grafana/dashboards
```

### Проверка Prometheus PVC

```bash
kubectl get pvc prometheus-pvc -n perf-lab
kubectl exec -n perf-lab deployment/prometheus -- sh -c 'ls -lah /prometheus && du -sh /prometheus'
```

---

## Текущий статус проекта

Проект завершён как **portfolio/lab v1**.

Реализовано:

- Spring Boot приложение;
- Docker Compose стенд;
- Kubernetes/k3s стенд;
- Prometheus + Grafana monitoring;
- exporters;
- PVC и ConfigMap;
- Grafana provisioning;
- Prometheus persistence;
- Ansible automation;
- Terraform cloud-ready слой;
- GitLab CI validation/build pipeline.

Дальше проект можно развивать в сторону:

- real cloud apply через Terraform;
- GitLab Runner и полноценный pipeline;
- Docker image push в registry;
- controlled deploy из CI;
- managed/cloud storage;
- long-term metrics через Thanos/Mimir/VictoriaMetrics.
