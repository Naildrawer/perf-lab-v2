# Java Performance Demo

Production-like лабораторный стенд для демонстрации навыков Performance Engineering, DevOps/SRE и Observability.

Проект показывает, как Java/Spring Boot приложение можно запустить в двух режимах — через Docker Compose и через Kubernetes/k3s — и вокруг него собрать воспроизводимую инфраструктуру наблюдаемости: Prometheus, Grafana, PostgreSQL/Redis exporters, Node Exporter, Nginx и Ansible playbooks.

## Цель проекта

Цель стенда — не просто запустить Java-приложение, а показать полный инженерный подход:

* приложение контейнеризовано через multi-stage Docker build;
* есть локальный Docker Compose режим для быстрого запуска;
* есть Kubernetes режим на k3s с manifests, probes, resources и services;
* инфраструктура запускается через Ansible;
* метрики собираются Prometheus;
* Grafana provisioned через файлы, без ручной настройки после старта;
* dashboards разделены под Docker Compose и Kubernetes;
* добавлен GitLab CI/CD pipeline для validate/build/docker/deploy стадий;
* PostgreSQL и Redis вынесены как отдельные сервисы;
* есть exporters для инфраструктурных метрик;
* конфигурация проекта хранится в репозитории и может быть воспроизведена на новой VM.

## Архитектура

```text
                    ┌────────────────────┐
                    │      Client        │
                    │ curl / browser     │
                    └─────────┬──────────┘
                              │
                              ▼
                    ┌────────────────────┐
                    │       Nginx        │
                    │ reverse proxy / LB │
                    └───────┬─────┬──────┘
                            │     │
                 ┌──────────▼┐   ┌▼──────────┐
                 │ Spring app │   │ Spring app │
                 │ instance 1 │   │ instance 2 │
                 └─────┬──────┘   └─────┬──────┘
                       │                │
                       └──────┬─────────┘
                              │
              ┌───────────────┴───────────────┐
              │                               │
              ▼                               ▼
        ┌────────────┐                 ┌────────────┐
        │ PostgreSQL │                 │   Redis    │
        └─────┬──────┘                 └─────┬──────┘
              │                              │
              ▼                              ▼
 ┌─────────────────────┐        ┌─────────────────────┐
 │ postgres-exporter   │        │ redis-exporter      │
 └──────────┬──────────┘        └──────────┬──────────┘
            │                              │
            └──────────────┬───────────────┘
                           │
                           ▼
                   ┌────────────┐
                   │ Prometheus │
                   └─────┬──────┘
                         │
                         ▼
                   ┌────────────┐
                   │  Grafana   │
                   └────────────┘
```

## Основные компоненты

### Spring Boot application

Приложение предоставляет REST API и Actuator endpoints:

* `/hello` — простой endpoint для проверки приложения;
* `/instance` — показывает hostname текущего инстанса;
* `/users` — CRUD API поверх PostgreSQL;
* `/actuator/health` — health endpoint;
* `/actuator/prometheus` — метрики для Prometheus.

Приложение запускается в двух экземплярах в Docker Compose режиме и в нескольких pod'ах в Kubernetes режиме. Это позволяет смотреть метрики не только агрегированно, но и по отдельным instance/pod.

### PostgreSQL

Используется как основная база данных для Spring Boot приложения. В Docker Compose режиме база инициализируется через `postgres/init.sql`.

Метрики PostgreSQL собираются через `postgres-exporter`.

### Redis

Redis используется как отдельный инфраструктурный сервис. Метрики Redis собираются через `redis-exporter`.

### Nginx

В Docker Compose режиме Nginx работает как reverse proxy и простой балансировщик между двумя экземплярами Spring Boot приложения.

Внешняя точка входа в Docker режиме:

```text
http://localhost:8088
```

### Prometheus

Prometheus собирает метрики приложения и инфраструктуры.

Основные scrape jobs в Docker Compose режиме:

* `spring` — Spring Boot Actuator metrics;
* `postgres` — PostgreSQL exporter;
* `redis` — Redis exporter;
* `node` — host metrics через Node Exporter;
* `prometheus` — self-monitoring Prometheus.

Основные scrape jobs в Kubernetes режиме:

* `spring` — Spring Boot pod metrics;
* `postgres` — PostgreSQL exporter;
* `redis` — Redis exporter;
* `node` — Node Exporter;
* `prometheus` — self-monitoring Prometheus.

### Grafana

Grafana поднимается с provisioning:

* datasource создаётся автоматически;
* dashboards загружаются из файлов;
* ручная настройка после запуска не нужна.

В проекте два основных dashboard:

* `Java Performance Docker Compose`;
* `Java Performance Kubernetes`.

## Структура проекта

```text
.
├── ansible/
│   ├── inventory.ini
│   └── playbooks/
│       ├── docker-up.yml
│       ├── docker-down.yml
│       ├── k8s-up.yml
│       ├── k8s-down.yml
│       ├── install-docker.yml
│       └── install-k3s.yml
│
├── app/
│   ├── Dockerfile
│   ├── pom.xml
│   └── src/
│
├── docker-compose.yml
├── .gitlab-ci.yml
│
├── grafana/
│   ├── dashboards/
│   │   ├── java-performance-docker-compose.json
│   │   └── java-performance-kubernetes.json
│   └── provisioning/
│       ├── dashboards/
│       └── datasources/
│
├── k8s/
│   ├── namespace.yaml
│   ├── app.yaml
│   ├── postgres.yaml
│   ├── redis.yaml
│   ├── nginx.yaml
│   ├── prometheus.yaml
│   ├── prometheus-config.yaml
│   ├── prometheus-rbac-service-view.yaml
│   ├── grafana.yaml
│   ├── grafana-dashboards.yaml
│   ├── postgres-exporter.yaml
│   ├── redis-exporter.yaml
│   └── node-exporter.yaml
│
├── nginx/
│   └── nginx.conf
│
├── postgres/
│   └── init.sql
│
├── prometheus/
│   ├── prometheus.yml
│   ├── prometheus-k8s.yml
│   └── prometheus-k8s-service-view.yml
│
└── README.md
```

## CI/CD pipeline

В проекте есть GitLab CI/CD pipeline в файле `.gitlab-ci.yml`. Он нужен, чтобы показать не только локальный запуск стенда, но и базовый production-like процесс проверки, сборки, публикации Docker image и деплоя в Kubernetes.

Pipeline состоит из четырёх стадий:

```text
validate -> build -> docker -> deploy
```

### Validate stage

На стадии `validate` выполняются статические проверки инфраструктурной части проекта.

`terraform:fmt` проверяет форматирование Terraform-кода:

```bash
terraform fmt -recursive -check terraform/
```

`terraform:validate` инициализирует Terraform без backend и проверяет конфигурацию окружения `terraform/environments/yandex`:

```bash
cd terraform/environments/yandex
terraform init -backend=false -upgrade
terraform validate
terraform providers
```

Для загрузки providers используется Terraform mirror Yandex Cloud через `.terraformrc`. Это делает pipeline более стабильным для окружения, где прямой доступ к registry может быть ограничен.

`ansible:syntax` проверяет синтаксис всех основных playbook'ов:

```bash
ansible-playbook --syntax-check playbooks/docker-up.yml
ansible-playbook --syntax-check playbooks/docker-down.yml
ansible-playbook --syntax-check playbooks/k8s-up.yml
ansible-playbook --syntax-check playbooks/k8s-down.yml
ansible-playbook --syntax-check playbooks/install-docker.yml
ansible-playbook --syntax-check playbooks/install-k3s.yml
```

`k8s:manifests:client-dry-run` проверяет Kubernetes manifests через client-side dry-run:

```bash
kubectl apply --dry-run=client -f k8s/namespace.yaml
kubectl apply --dry-run=client -f k8s/app.yaml
kubectl apply --dry-run=client -f k8s/prometheus.yaml
kubectl apply --dry-run=client -f k8s/grafana.yaml
```

В реальном pipeline проверяются все основные manifests: namespace, PostgreSQL, Redis, приложение, exporters, Prometheus, Grafana, dashboards и ingress.

### Build stage

На стадии `build` собирается Spring Boot приложение через Maven:

```bash
cd app
mvn -B clean package -DskipTests
```

Собранный `.jar` сохраняется как GitLab artifact на одну неделю:

```text
app/target/\*.jar
```

### Docker stage

На стадии `docker` есть две задачи.

`docker:compose:config` валидирует итоговую Docker Compose конфигурацию:

```bash
docker compose -f docker-compose.yml config
```

`docker:build:push` собирает Docker image приложения и публикует его в GitLab Container Registry. Image получает два tag'а:

```text
$CI\_REGISTRY\_IMAGE/app:$CI\_COMMIT\_SHORT\_SHA
$CI\_REGISTRY\_IMAGE/app:$CI\_COMMIT\_REF\_SLUG
```

Это позволяет использовать как immutable tag на конкретный commit, так и branch tag для текущей ветки.

### Deploy stage

Стадия `deploy` рассчитана на локальный GitLab Runner с tag'ом:

```text
local-deploy
```

Job `deploy:k8s` использует kubeconfig раннера:

```bash
export KUBECONFIG=/home/gitlab-runner/.kube/config
```

Дальше pipeline:

* применяет namespace `perf-lab`;
* создаёт/обновляет `docker-registry` secret для GitLab Registry;
* добавляет `imagePullSecrets` в default service account;
* применяет manifests PostgreSQL, Redis и приложения;
* обновляет image deployment'а `app` на image текущего commit'а;
* ждёт rollout deployment'а;
* выводит pod'ы приложения.

Деплой сделан manual и запускается только для ветки:

```text
perf-lab-dev
```

Это безопаснее для учебного стенда: validate/build/docker могут выполняться автоматически, а фактический deploy в локальный k3s выполняется вручную, когда VM и runner готовы.

### Что демонстрирует CI/CD часть

CI/CD часть показывает, что проект можно не только поднять вручную, но и прогнать через базовый инженерный pipeline:

* проверить Terraform formatting и validate;
* проверить Ansible playbooks;
* проверить Kubernetes manifests до применения;
* собрать Spring Boot приложение;
* собрать и запушить Docker image;
* выполнить ручной deploy в Kubernetes через GitLab Runner;
* обновить deployment на image конкретного commit'а;
* дождаться rollout и проверить состояние pod'ов.

## Режимы запуска

Проект поддерживает два режима:

1. Docker Compose mode — быстрый локальный стенд.
2. Kubernetes mode — production-like запуск через k3s.

На одной VM лучше не держать оба режима одновременно. Перед запуском Docker режима playbook останавливает k3s. Перед запуском Kubernetes режима playbook останавливает Docker Compose контейнеры.

## Docker Compose mode

### Запуск

```bash
cd \~/training/java-performance-demo/ansible
sudo ansible-playbook playbooks/docker-up.yml
```

Playbook делает следующее:

* останавливает k3s перед Docker mode;
* останавливает старые Docker Compose контейнеры;
* собирает Spring Boot image;
* поднимает весь Docker Compose стек;
* проверяет health endpoint приложения;
* проверяет корректный `404` для несуществующего пользователя;
* проверяет готовность Prometheus;
* проверяет Grafana API;
* проверяет, что Prometheus видит основные targets.

### Остановка

```bash
cd \~/training/java-performance-demo/ansible
sudo ansible-playbook playbooks/docker-down.yml
```

### URL в Docker режиме

```text
Application via Nginx: http://localhost:8088
Spring health:          http://localhost:8088/actuator/health
Prometheus:             http://localhost:9090
Grafana:                http://localhost:3000
Node Exporter:          http://localhost:9101/metrics
Postgres Exporter:      http://localhost:9187/metrics
Redis Exporter:         http://localhost:9121/metrics
```

Grafana credentials:

```text
login:    admin
password: admin
```

### Быстрые проверки Docker режима

```bash
curl --max-time 10 http://localhost:8088/actuator/health
curl --max-time 10 http://localhost:8088/users
curl --max-time 10 http://localhost:9090/-/ready
curl --max-time 10 http://localhost:3000/api/health
```

Проверка Prometheus targets:

```bash
curl -s 'http://localhost:9090/api/v1/query?query=up' | python3 -m json.tool
```

Проверка dashboard provisioning:

```bash
curl -s -u admin:admin http://localhost:3000/api/search?type=dash-db | python3 -m json.tool
```

Ожидаемые dashboards:

```text
Java Performance Docker Compose
Java Performance Kubernetes
```

## Kubernetes mode

Kubernetes режим рассчитан на локальный k3s.

### Запуск

```bash
cd \~/training/java-performance-demo/ansible
sudo ansible-playbook playbooks/k8s-up.yml
```

Playbook делает следующее:

* останавливает Docker Compose перед Kubernetes mode;
* запускает k3s;
* собирает Docker image приложения;
* импортирует image в k3s containerd;
* применяет Kubernetes manifests;
* ждёт rollout основных deployment'ов;
* проверяет доступность приложения;
* проверяет Prometheus;
* проверяет Grafana;
* проверяет наличие нужных Prometheus targets.

### Остановка

```bash
cd \~/training/java-performance-demo/ansible
sudo ansible-playbook playbooks/k8s-down.yml
```

### URL в Kubernetes режиме

```text
Application via Nginx NodePort: http://localhost:30080
Prometheus NodePort:            http://localhost:30090
Grafana NodePort:               http://localhost:30030
```

Grafana credentials:

```text
login:    admin
password: admin
```

### Быстрые проверки Kubernetes режима

```bash
kubectl get pods -n perf-lab
kubectl get svc -n perf-lab
kubectl get deploy -n perf-lab
```

Проверка приложения:

```bash
curl --max-time 10 http://localhost:30080/actuator/health
curl --max-time 10 http://localhost:30080/users
```

Проверка Prometheus:

```bash
curl --max-time 10 http://localhost:30090/-/ready
curl -s 'http://localhost:30090/api/v1/query?query=up' | python3 -m json.tool
```

Проверка Grafana:

```bash
curl --max-time 10 http://localhost:30030/api/health
curl -s -u admin:admin http://localhost:30030/api/search?type=dash-db | python3 -m json.tool
```

## Grafana dashboards

### Java Performance Docker Compose

Dashboard для Docker Compose режима показывает:

* Spring Boot target status;
* RPS по instance;
* HTTP 4xx/5xx;
* average response time;
* total requests;
* JVM heap/non-heap memory;
* heap usage percent;
* live/peak threads;
* GC pause time;
* process CPU;
* process memory;
* HikariCP active/idle/pending/max/min connections;
* PostgreSQL exporter metrics;
* Redis exporter metrics;
* Node Exporter host metrics;
* Prometheus scrape status.

### Java Performance Kubernetes

Dashboard для Kubernetes режима показывает:

* Spring pod target status;
* RPS по pod;
* HTTP 4xx/5xx;
* average response time;
* total requests;
* JVM heap/non-heap memory по pod;
* heap usage percent;
* threads;
* GC pause time;
* process CPU;
* process memory;
* HikariCP metrics;
* PostgreSQL exporter metrics;
* Redis exporter metrics;
* Node Exporter metrics;
* Prometheus scrape status.

## Prometheus queries для проверки

Docker Compose mode:

```promql
up
up{job="spring"}
up{job="postgres"}
up{job="redis"}
up{job="node"}
rate(http\_server\_requests\_seconds\_count{job="spring"}\[1m])
jvm\_memory\_used\_bytes{job="spring",area="heap"}
hikaricp\_connections\_active{job="spring"}
```

Kubernetes mode:

```promql
up
up{job="spring"}
rate(http\_server\_requests\_seconds\_count{job="spring"}\[1m])
sum by(pod) (jvm\_memory\_used\_bytes{job="spring",area="heap"})
hikaricp\_connections\_active{job="spring"}
```

## API examples

Получить пользователей:

```bash
curl http://localhost:8088/users
```

Создать пользователя:

```bash
curl -X POST http://localhost:8088/users \\
  -H 'Content-Type: application/json' \\
  -d '{"name":"Max","email":"max@example.com"}'
```

Проверить балансировку между instance:

```bash
for i in {1..10}; do curl -s http://localhost:8088/instance; echo; done
```

Проверить `404`:

```bash
curl -i http://localhost:8088/users/999999999
```

## Типовые проблемы и диагностика

### Grafana показывает старые dashboards

Grafana хранит импортированные dashboards во внутренней базе на volume. Если dashboard-файлы заменены, но UI показывает старые версии, можно пересоздать только Grafana volume.

Docker mode:

```bash
docker compose stop grafana
docker compose rm -f grafana
docker volume rm java-performance-demo\_grafana-data
docker compose up -d grafana
```

Kubernetes mode:

```bash
kubectl scale deployment/grafana -n perf-lab --replicas=0
kubectl delete pvc grafana-pvc -n perf-lab --ignore-not-found=true
kubectl apply -f k8s/grafana.yaml
kubectl apply -f k8s/grafana-dashboards.yaml
kubectl scale deployment/grafana -n perf-lab --replicas=1
kubectl rollout status deployment/grafana -n perf-lab --timeout=180s
```

### Prometheus не видит приложение

Docker mode:

```bash
docker ps
curl http://localhost:8088/actuator/health
curl http://localhost:8088/actuator/prometheus | head
curl -s 'http://localhost:9090/api/v1/query?query=up%7Bjob%3D%22spring%22%7D' | python3 -m json.tool
```

Kubernetes mode:

```bash
kubectl get pods -n perf-lab
kubectl get svc -n perf-lab
kubectl logs -n perf-lab deploy/prometheus --tail=100
curl -s 'http://localhost:30090/api/v1/query?query=up%7Bjob%3D%22spring%22%7D' | python3 -m json.tool
```

### Ansible зависает на rollout

Проверить pod'ы:

```bash
kubectl get pods -n perf-lab -o wide
kubectl describe pod -n perf-lab <pod-name>
kubectl logs -n perf-lab <pod-name> --tail=100
```

Если проблема с Prometheus/Grafana и PVC, проверить, что deployment использует стратегию `Recreate`, чтобы два pod'а не пытались одновременно использовать один volume.

### Docker команды зависают

На маленькой VM не стоит одновременно держать Docker Compose и k3s. Переключай режимы через playbooks.

Для Docker mode:

```bash
cd \~/training/java-performance-demo/ansible
sudo ansible-playbook playbooks/docker-up.yml
```

Для Kubernetes mode:

```bash
cd \~/training/java-performance-demo/ansible
sudo ansible-playbook playbooks/k8s-up.yml
```

## Что этот проект демонстрирует

Проект демонстрирует практические навыки:

* Docker и Docker Compose;
* multi-stage Docker build;
* Kubernetes manifests;
* k3s;
* Ansible automation;
* Prometheus scraping;
* Grafana provisioning;
* JVM metrics;
* Spring Boot Actuator;
* PostgreSQL и Redis exporters;
* Node Exporter;
* GitLab CI/CD pipeline;
* Terraform fmt/validate;
* Docker image build/push в Container Registry;
* manual deploy в Kubernetes через локальный GitLab Runner;
* reverse proxy через Nginx;
* health checks;
* readiness/liveness probes;
* resources requests/limits;
* troubleshooting observability stack;
* разделение Docker и Kubernetes режимов;
* воспроизводимость стенда из репозитория.

