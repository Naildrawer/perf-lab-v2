# Java Performance Demo

Production-like лабораторный стенд для демонстрации навыков Performance Engineering, DevOps/SRE, Observability и CI/CD.

Проект показывает полный путь от Spring Boot приложения до воспроизводимого стенда: контейнеризация, Docker Compose, Kubernetes/k3s, Ansible automation, Prometheus, Grafana dashboards, PostgreSQL/Redis exporters, Terraform validation и GitLab CI/CD с публикацией Docker image и manual deploy в локальный k3s.

## Что демонстрирует проект

Проект сделан не как простой `docker run`, а как полноценный инженерный стенд:

* Java/Spring Boot приложение собрано через multi-stage Docker build;
* приложение работает с PostgreSQL и Redis;
* есть Docker Compose режим для быстрого локального запуска;
* есть Kubernetes/k3s режим с manifests, probes, resources, PVC и services;
* запуск и переключение режимов автоматизированы через Ansible;
* метрики собираются через Prometheus;
* Grafana datasource и dashboards создаются через provisioning;
* dashboards разделены под Docker Compose и Kubernetes;
* PostgreSQL, Redis и host metrics собираются через exporters;
* GitLab CI/CD проверяет Terraform, Ansible, Kubernetes manifests, собирает приложение, публикует Docker image и деплоит в k3s через local runner;
* проект можно поднять на новой VM из репозитория.

## Архитектура Docker Compose режима

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

В Docker Compose режиме Nginx балансирует запросы между двумя экземплярами Spring Boot приложения. Это позволяет смотреть метрики по отдельным instance и проверять балансировку через endpoint `/instance`.

## Архитектура Kubernetes режима

```text
                   ┌────────────────────┐
                   │      Client        │
                   │ curl / browser     │
                   └─────────┬──────────┘
                             │
                             ▼
                   ┌────────────────────┐
                   │ Service app        │
                   │ NodePort 30080     │
                   └─────────┬──────────┘
                             │
              ┌──────────────┴──────────────┐
              ▼                             ▼
       ┌─────────────┐               ┌─────────────┐
       │ Spring pod  │               │ Spring pod  │
       └──────┬──────┘               └──────┬──────┘
              │                             │
              └──────────────┬──────────────┘
                             │
              ┌──────────────┴──────────────┐
              ▼                             ▼
       ┌─────────────┐               ┌─────────────┐
       │ PostgreSQL  │               │    Redis    │
       │ PVC-backed  │               │ PVC-backed  │
       └──────┬──────┘               └──────┬──────┘
              │                             │
              ▼                             ▼
   ┌───────────────────┐         ┌───────────────────┐
   │ postgres-exporter │         │ redis-exporter    │
   └─────────┬─────────┘         └─────────┬─────────┘
             │                             │
             └──────────────┬──────────────┘
                            ▼
                    ┌────────────┐
                    │ Prometheus │
                    │ NodePort   │
                    │ 30090      │
                    └─────┬──────┘
                          ▼
                    ┌────────────┐
                    │ Grafana    │
                    │ NodePort   │
                    │ 30030      │
                    └────────────┘
```

Kubernetes режим рассчитан на локальный k3s. В нём используются namespace, Deployment, Service, PVC, Secret, ConfigMap, readiness/liveness/startup probes, requests/limits и RBAC для Prometheus.

## Основные компоненты

### Spring Boot application

Приложение предоставляет REST API и Actuator endpoints:

* `/hello` — простой endpoint для проверки приложения;
* `/instance` — hostname текущего instance/pod;
* `/users` — CRUD API поверх PostgreSQL;
* `/actuator/health` — health endpoint;
* `/actuator/prometheus` — метрики для Prometheus.

В Docker Compose режиме приложение запускается в двух контейнерах: `spring-app` и `spring-app-2`.

В Kubernetes режиме приложение запускается как `Deployment app` с двумя pod'ами.

### PostgreSQL

PostgreSQL используется как основная база данных приложения.

В Docker Compose режиме база инициализируется через:

```text
postgres/init.sql
```

В Kubernetes режиме init SQL хранится в ConfigMap `postgres-init-sql`, а данные PostgreSQL лежат в PVC `postgres-pvc`.

Метрики PostgreSQL собираются через `postgres-exporter`.

### Redis

Redis используется как отдельный инфраструктурный сервис. В Kubernetes режиме он также использует PVC.

Метрики Redis собираются через `redis-exporter`.

### Node Exporter

Node Exporter собирает host-level метрики VM: CPU, memory, filesystem, load average и сетевые показатели хоста.

### Prometheus

Prometheus собирает метрики приложения и инфраструктуры.

Основные scrape jobs:

```text
spring
postgres
redis
node
prometheus
```

В Docker Compose режиме Prometheus доступен на:

```text
http://localhost:9090
```

В Kubernetes режиме Prometheus доступен через NodePort:

```text
http://localhost:30090
```

### Grafana

Grafana поднимается с provisioning:

* datasource создаётся автоматически;
* dashboard provider создаётся автоматически;
* dashboards загружаются из JSON-файлов;
* ручная настройка после старта не требуется.

В проекте два dashboard:

```text
Java Performance Docker Compose
Java Performance Kubernetes
```

Grafana credentials:

```text
login:    admin
password: admin
```

## Kubernetes secrets

В проекте используется два типа secret'ов.

### 1\. `app-secrets`

Secret `app-secrets` описан в Kubernetes manifests и применяется вместе с PostgreSQL manifest:

```bash
kubectl apply -f k8s/postgres.yaml
```

Он содержит demo-значения для PostgreSQL, Spring datasource и postgres-exporter:

```text
POSTGRES\_DB
POSTGRES\_USER
POSTGRES\_PASSWORD
SPRING\_DATASOURCE\_USERNAME
SPRING\_DATASOURCE\_PASSWORD
POSTGRES\_EXPORTER\_DATA\_SOURCE\_NAME
```

PostgreSQL берёт из него переменные:

```text
POSTGRES\_DB
POSTGRES\_USER
POSTGRES\_PASSWORD
```

Spring Boot приложение берёт из него:

```text
SPRING\_DATASOURCE\_USERNAME
SPRING\_DATASOURCE\_PASSWORD
```

То есть в Kubernetes режиме приложение подключается к PostgreSQL не через hardcoded env в Deployment, а через `secretKeyRef`.

### 2\. `gitlab-registry`

Secret `gitlab-registry` создаётся динамически в GitLab CI/CD на этапе `deploy:k8s`:

```bash
kubectl -n perf-lab create secret docker-registry gitlab-registry \\
  --docker-server="$CI\_REGISTRY" \\
  --docker-username="$REGISTRY\_USERNAME" \\
  --docker-password="$REGISTRY\_PASSWORD\_VALUE" \\
  --dry-run=client -o yaml | kubectl apply -f -
```

После создания secret pipeline патчит default service account:

```bash
kubectl -n perf-lab patch serviceaccount default -p '{"imagePullSecrets":\[{"name":"gitlab-registry"}]}' || true
```

Это нужно, чтобы k3s мог скачивать приватный Docker image приложения из GitLab Container Registry.

В учебном стенде demo-секреты лежат в manifest'ах. Для production-подхода секреты обычно выносят в CI/CD variables, External Secrets, Sealed Secrets, Vault или другой secret management инструмент.

## Структура проекта

```text
.
├── .gitlab-ci.yml
├── docker-compose.yml
├── README.md
│
├── ansible/
│   ├── ansible.cfg
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
│   ├── postgres-exporter.yaml
│   ├── redis-exporter.yaml
│   ├── node-exporter.yaml
│   ├── prometheus-rbac-service-view.yaml
│   ├── prometheus-config.yaml
│   ├── prometheus.yaml
│   ├── grafana-datasources.yaml
│   ├── grafana-dashboard-providers.yaml
│   ├── grafana-dashboards.yaml
│   ├── grafana.yaml
│   └── ingress.yaml
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
└── terraform/
    ├── README.md
    └── environments/
```

## CI/CD pipeline

В проекте настроен GitLab CI/CD pipeline в `.gitlab-ci.yml`.

Pipeline состоит из четырёх стадий:

```text
validate -> build -> docker -> deploy
```

### Validate stage

На стадии `validate` выполняются проверки инфраструктурной части проекта.

#### `terraform:fmt`

Проверяет форматирование Terraform-кода:

```bash
terraform fmt -recursive -check terraform/
```

#### `terraform:validate`

Инициализирует Terraform без backend и проверяет конфигурацию окружения:

```bash
cd terraform/environments/yandex
terraform init -backend=false -upgrade
terraform validate
terraform providers
```

Для загрузки providers используется Terraform mirror Yandex Cloud через `.terraformrc`.

#### `ansible:syntax`

Проверяет синтаксис Ansible playbook'ов:

```bash
ansible-playbook --syntax-check playbooks/docker-up.yml
ansible-playbook --syntax-check playbooks/docker-down.yml
ansible-playbook --syntax-check playbooks/k8s-up.yml
ansible-playbook --syntax-check playbooks/k8s-down.yml
ansible-playbook --syntax-check playbooks/install-docker.yml
ansible-playbook --syntax-check playbooks/install-k3s.yml
```

#### `k8s:manifests:kubeconform`

Проверяет Kubernetes manifests через `kubeconform` без подключения к живому Kubernetes API:

```bash
kubeconform -summary -verbose -strict -ignore-missing-schemas -kubernetes-version 1.31.0 k8s/\*.yaml
```

Это важно для shared GitLab Runner, где нет доступа к локальному k3s API.

### Build stage

#### `spring:build`

Собирает Spring Boot приложение через Maven:

```bash
cd app
mvn -B clean package -DskipTests
```

Собранный `.jar` сохраняется как artifact:

```text
app/target/\*.jar
```

### Docker stage

#### `docker:compose:config`

Проверяет итоговую Docker Compose конфигурацию:

```bash
docker compose -f docker-compose.yml config
```

#### `docker:build:push`

Собирает Docker image приложения и публикует его в GitLab Container Registry:

```bash
DOCKER\_BUILDKIT=1 docker build -t "$APP\_IMAGE" -t "$APP\_IMAGE\_BRANCH" ./app
docker push "$APP\_IMAGE"
docker push "$APP\_IMAGE\_BRANCH"
```

Image получает два tag'а:

```text
$CI\_REGISTRY\_IMAGE/app:$CI\_COMMIT\_SHORT\_SHA
$CI\_REGISTRY\_IMAGE/app:$CI\_COMMIT\_REF\_SLUG
```

Первый tag привязан к конкретному commit'у, второй — к ветке.

### Deploy stage

#### `deploy:k8s`

Deploy выполняется на локальном GitLab Runner с tag'ом:

```text
local-deploy
```

Job использует kubeconfig раннера:

```bash
export KUBECONFIG=/home/gitlab-runner/.kube/config
```

Перед deploy job проверяет доступность local k3s API. Если API недоступен, pipeline пытается запустить k3s через systemd:

```bash
sudo -n systemctl start k3s
```

Для этого на VM должен быть разрешён passwordless sudo для пользователя `gitlab-runner` на команду запуска k3s.

Дальше job:

* применяет namespace `perf-lab`;
* создаёт/обновляет Docker registry secret `gitlab-registry`;
* добавляет `imagePullSecrets` в default service account;
* применяет manifests PostgreSQL, Redis, приложения, exporters, Prometheus и Grafana;
* обновляет image deployment'а `app` на image текущего commit'а;
* пересоздаёт ConfigMap `grafana-dashboards` из dashboard JSON-файлов;
* делает rollout restart Grafana;
* ждёт rollout основных deployment'ов;
* выводит состояние pod'ов и services.

Dashboard ConfigMap в CI создаётся через `kubectl create configmap --from-file`, а не через `kubectl apply -f k8s/grafana-dashboards.yaml`. Это сделано потому, что dashboard JSON-файлы большие, и `kubectl apply` может упереться в лимит размера annotations.

Deploy сделан ручным и запускается только для ветки:

```text
perf-lab-dev
```

Правило запуска:

```yaml
rules:
  - if: '$CI\_COMMIT\_BRANCH == "perf-lab-dev"'
    when: manual
```

Для защиты от параллельных деплоев используется:

```yaml
resource\_group: local-k3s
```

## Режимы запуска

Проект поддерживает два режима:

1. Docker Compose mode — быстрый локальный стенд.
2. Kubernetes mode — production-like запуск через k3s.

На одной небольшой VM лучше не держать оба режима одновременно. Перед запуском Docker режима playbook останавливает k3s. Перед запуском Kubernetes режима playbook останавливает Docker Compose контейнеры.

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
* поднимает Docker Compose стек;
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

## Kubernetes mode

### Запуск через Ansible

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

### Deploy через GitLab CI/CD

Для deploy через pipeline используется manual job `deploy:k8s`.

Он запускается на local runner `ubuntu123` с tag'ом `local-deploy`, собирает image в GitLab Container Registry, создаёт registry secret в Kubernetes и обновляет deployment `app` на image текущего commit'а.

Успешный deploy заканчивается выводом:

```text
deployment "app" successfully rolled out
deployment "postgres" successfully rolled out
deployment "redis" successfully rolled out
deployment "prometheus" successfully rolled out
deployment "grafana" successfully rolled out
Job succeeded
```

### Остановка

```bash
cd \~/training/java-performance-demo/ansible
sudo ansible-playbook playbooks/k8s-down.yml
```

### URL в Kubernetes режиме

```text
Application NodePort: http://localhost:30080
Prometheus NodePort: http://localhost:30090
Grafana NodePort:    http://localhost:30030
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
* live/peak threads;
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

## Работа с PostgreSQL

Docker Compose mode:

```bash
docker exec -it postgres psql -U app -d app
```

Kubernetes mode:

```bash
kubectl exec -it -n perf-lab deploy/postgres -- psql -U app -d app
```

Полезные команды внутри `psql`:

```sql
\\dt
SELECT \* FROM users;
\\d users
\\q
```

## Типовые проблемы и диагностика

### Grafana показывает старые dashboards

Grafana хранит импортированные dashboards во внутренней базе на volume/PVC. Если dashboard-файлы заменены, но UI показывает старые версии, можно пересоздать только хранилище Grafana.

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
kubectl scale deployment/grafana -n perf-lab --replicas=1
kubectl rollout status deployment/grafana -n perf-lab --timeout=180s
```

### GitLab deploy не может скачать image

Проверить registry secret:

```bash
kubectl get secret gitlab-registry -n perf-lab
kubectl get serviceaccount default -n perf-lab -o yaml | grep -A5 imagePullSecrets
```

Если secret отсутствует, перезапустить manual job `deploy:k8s` или создать secret вручную.

### GitLab deploy не видит k3s API

Проверить k3s на VM:

```bash
sudo systemctl status k3s
sudo systemctl start k3s
kubectl get nodes
```

Проверить от пользователя `gitlab-runner`:

```bash
sudo -u gitlab-runner KUBECONFIG=/home/gitlab-runner/.kube/config kubectl get nodes
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

Проверить pod'ы и events:

```bash
kubectl get pods -n perf-lab -o wide
kubectl describe pod -n perf-lab <pod-name>
kubectl logs -n perf-lab <pod-name> --tail=100
```

### Docker команды зависают

На маленькой VM не стоит одновременно держать Docker Compose и k3s. Переключай режимы через playbooks:

```bash
cd \~/training/java-performance-demo/ansible
sudo ansible-playbook playbooks/docker-up.yml
```

или:

```bash
cd \~/training/java-performance-demo/ansible
sudo ansible-playbook playbooks/k8s-up.yml
```

## Что этот проект демонстрирует

Проект демонстрирует практические навыки:

* Java/Spring Boot;
* REST API;
* Spring Boot Actuator;
* Docker и Docker Compose;
* multi-stage Docker build;
* Nginx reverse proxy;
* PostgreSQL и Redis;
* Kubernetes manifests;
* k3s;
* Kubernetes Secret, ConfigMap, PVC, Service, Deployment;
* readiness/liveness/startup probes;
* resource requests/limits;
* Ansible automation;
* Prometheus scraping;
* Grafana provisioning;
* PostgreSQL/Redis/Node exporters;
* GitLab CI/CD pipeline;
* Terraform fmt/validate;
* Docker image build/push в GitLab Container Registry;
* manual deploy в Kubernetes через локальный GitLab Runner;
* imagePullSecrets для приватного registry;
* rollout status и basic deployment verification;
* troubleshooting observability stack;
* воспроизводимость стенда из репозитория.

