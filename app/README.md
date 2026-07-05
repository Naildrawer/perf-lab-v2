# Java Performance Lab

Учебный production-like стенд для демонстрации навыков Performance Engineering, Observability, Docker, Kubernetes, Ansible, Prometheus и Grafana.

Проект показывает не просто запуск Java-приложения, а полный воспроизводимый контур: приложение, база данных, кеш, балансировка, метрики, exporters, dashboards, Docker Compose режим, Kubernetes/k3s режим и автоматизация через Ansible.

## Что входит в проект

| Компонент | Назначение |
|---|---|
| Spring Boot app | Demo API с REST endpoints и Actuator/Prometheus метриками |
| PostgreSQL | Основная БД приложения |
| Redis | Инфраструктурный кеш/сервис для демонстрации зависимости и exporter'а |
| Nginx | Балансировка между двумя инстансами приложения в Docker Compose |
| Prometheus | Сбор метрик приложения, БД, Redis и хоста |
| Grafana | Dashboard provisioning и визуализация метрик |
| Node Exporter | Метрики хоста/VM |
| PostgreSQL Exporter | Метрики PostgreSQL |
| Redis Exporter | Метрики Redis |
| Kubernetes/k3s | Второй режим запуска приложения в кластере |
| Ansible | Автоматический запуск Docker и Kubernetes режимов |
| Terraform | Заготовка IaC под инфраструктуру в Yandex Cloud |
| GitLab CI | Проверки Terraform, Ansible, Kubernetes manifests и Docker build |

## Зачем этот проект нужен

Это портфолио-проект под роли:

- Performance Engineer;
- Observability Engineer;
- SRE Junior+/Middle-;
- DevOps Junior+/Middle-;
- Monitoring Engineer.

В проекте сделан акцент на то, что обычно спрашивают на собеседованиях:

- как приложение отдаёт метрики;
- как Prometheus находит targets;
- чем отличаются app metrics, DB metrics, Redis metrics и host metrics;
- как работает dashboard provisioning в Grafana;
- как воспроизводимо поднять стенд;
- как переключаться между Docker Compose и Kubernetes;
- как не держать одновременно Docker Compose и k3s на слабой VM;
- зачем нужны probes, resources, PVC, Secret, ConfigMap и RBAC.

## Архитектура Docker Compose режима

Docker Compose режим предназначен для быстрой локальной демонстрации.

```text
User
  |
  v
localhost:8088
  |
  v
Nginx
  |-------------------|
  v                   v
spring-app        spring-app-2
  |                   |
  |-------------------|
          |
          v
      PostgreSQL
          |
          v
        Redis

Prometheus scrapes:
  - spring-app:8080/actuator/prometheus
  - spring-app-2:8080/actuator/prometheus
  - postgres-exporter:9187
  - redis-exporter:9121
  - node-exporter:9100

Grafana reads Prometheus and provisions dashboards from files.
```

Открытые порты Docker режима:

| Сервис | URL |
|---|---|
| Application через Nginx | http://localhost:8088 |
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3000 |
| PostgreSQL | localhost:5432 |
| Redis | localhost:6379 |
| PostgreSQL Exporter | http://localhost:9187/metrics |
| Redis Exporter | http://localhost:9121/metrics |
| Node Exporter | http://localhost:9101/metrics |

Логин Grafana:

```text
admin / admin
```

## Почему в Docker режиме нет cAdvisor

cAdvisor намеренно удалён из итоговой версии проекта.

На локальной VM с Docker + k3s + containerd + cgroup v2 он давал нестабильную картину: вместо Docker Compose labels отдавал в основном `kubepods.slice`, а Docker metadata не подтягивалась. Из-за этого Docker dashboard строился по ненадёжным labels и показывал `No data`.

Итоговое решение стабильнее:

- Docker dashboard строится по application/JVM/HikariCP/PostgreSQL/Redis/host metrics;
- host metrics даёт Node Exporter;
- БД и Redis покрыты dedicated exporters;
- Kubernetes режим не зависит от Docker cAdvisor;
- проект становится проще запускать и объяснять на собеседовании.

Это осознанный trade-off: меньше нестабильной container-level детализации, зато полностью воспроизводимый observability pipeline.

## Архитектура Kubernetes режима

Kubernetes режим запускается в локальном k3s.

```text
localhost:30080
  |
  v
Service app NodePort
  |
  v
Deployment app, replicas=2
  |
  |---- PostgreSQL Deployment + PVC
  |---- Redis Deployment + PVC

Prometheus:
  - pod discovery для Spring Boot app
  - postgres-exporter
  - redis-exporter
  - node-exporter

Grafana:
  - datasource через ConfigMap
  - dashboard provider через ConfigMap
  - dashboards через ConfigMap
  - данные Grafana через PVC
```

Открытые порты Kubernetes режима:

| Сервис | URL |
|---|---|
| Application | http://localhost:30080 |
| Prometheus | http://localhost:30090 |
| Grafana | http://localhost:30030 |

## Режимы запуска

На слабой VM лучше не держать Docker Compose и Kubernetes одновременно.

Правило проекта:

- Docker режим выключает k3s;
- Kubernetes режим выключает Docker Compose;
- переключение делается через Ansible.

## Запуск Docker Compose режима

Из корня проекта:

```bash
cd ~/training/java-performance-demo/ansible
sudo ansible-playbook playbooks/docker-up.yml
```

Проверки:

```bash
curl --max-time 10 http://localhost:8088/instance
curl --max-time 10 http://localhost:8088/actuator/health
curl -i --max-time 10 http://localhost:8088/users/999999999
curl --max-time 10 http://localhost:9090/-/ready
curl --max-time 10 http://localhost:3000/api/health
```

Ожидаемо:

- `/actuator/health` возвращает HTTP 200;
- `/users/999999999` возвращает HTTP 404;
- `/instance` по очереди может возвращать `app` и `app2`, если Nginx балансирует запросы между двумя контейнерами.

Остановить Docker режим:

```bash
cd ~/training/java-performance-demo/ansible
sudo ansible-playbook playbooks/docker-down.yml
```

## Запуск Kubernetes режима

```bash
cd ~/training/java-performance-demo/ansible
sudo ansible-playbook playbooks/k8s-up.yml
```

Проверки:

```bash
kubectl get pods -n perf-lab -o wide
kubectl get svc -n perf-lab
kubectl get pvc -n perf-lab

curl --max-time 10 http://localhost:30080/actuator/health
curl -i --max-time 10 http://localhost:30080/users/999999999
curl --max-time 10 http://localhost:30090/-/ready
curl --max-time 10 http://localhost:30030/api/health
```

Остановить Kubernetes режим:

```bash
cd ~/training/java-performance-demo/ansible
sudo ansible-playbook playbooks/k8s-down.yml
```

## Docker build

Приложение собирается multi-stage Dockerfile:

```text
maven:3.9.9-eclipse-temurin-17 -> eclipse-temurin:17-jre-jammy
```

В Dockerfile используется BuildKit cache mount для Maven cache:

```dockerfile
RUN --mount=type=cache,target=/root/.m2 mvn -B -DskipTests dependency:go-offline
RUN --mount=type=cache,target=/root/.m2 mvn -B -DskipTests clean package
```

Первый build может быть дольше, следующие должны идти быстро за счёт cache.

Ручная сборка:

```bash
DOCKER_BUILDKIT=1 docker build -t java-performance-demo-app:local app
```

## Grafana dashboards

В проекте два dashboard файла:

```text
grafana/dashboards/java-performance-docker-compose.json
grafana/dashboards/java-performance-kubernetes.json
```

Docker Compose Grafana читает dashboards из bind mount:

```text
./grafana/dashboards:/var/lib/grafana/dashboards:ro
```

Kubernetes Grafana получает dashboards из ConfigMap:

```text
k8s/grafana-dashboards.yaml
```

Если в Docker режиме видны старые dashboards, нужно очистить только Grafana volume:

```bash
cd ~/training/java-performance-demo
docker compose stop grafana
docker compose rm -f grafana
docker volume rm java-performance-demo_grafana-data
docker compose up -d grafana
```

Если в Kubernetes режиме видны старые dashboards, нужно очистить только Grafana PVC:

```bash
kubectl scale deployment/grafana -n perf-lab --replicas=0
kubectl delete pvc grafana-pvc -n perf-lab
kubectl apply -f k8s/grafana.yaml
kubectl apply -f k8s/grafana-dashboards.yaml
kubectl scale deployment/grafana -n perf-lab --replicas=1
kubectl rollout status deployment/grafana -n perf-lab --timeout=180s
```

## Prometheus jobs

Docker Compose Prometheus собирает:

| Job | Target |
|---|---|
| spring | app:8080, app2:8080 |
| postgres | postgres-exporter:9187 |
| redis | redis-exporter:9121 |
| node | node-exporter:9100 |

Kubernetes Prometheus собирает:

| Job | Target |
|---|---|
| spring | pod discovery по label `app=spring` |
| postgres | postgres-exporter:9187 |
| redis | redis-exporter:9121 |
| node | node-exporter:9100 |

Проверить targets:

Docker:

```bash
curl -s http://localhost:9090/api/v1/targets | python3 -m json.tool
```

Kubernetes:

```bash
curl -s http://localhost:30090/api/v1/targets | python3 -m json.tool
```

## API приложения

Основные endpoints:

```text
GET    /hello
GET    /instance
GET    /users
GET    /users/{id}
POST   /users
PUT    /users/{id}
DELETE /users/{id}
GET    /actuator/health
GET    /actuator/prometheus
```

Пример создания пользователя:

```bash
curl -i -X POST http://localhost:8088/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Maksim","email":"maksim@example.com"}'
```

Пример проверки 404:

```bash
curl -i http://localhost:8088/users/999999999
```

## PostgreSQL

В Docker Compose данные PostgreSQL лежат в volume:

```text
pgdata
```

Инициализация таблицы идёт из:

```text
postgres/init.sql
```

В Kubernetes используется PVC:

```text
postgres-pvc
```

## Redis

Redis используется как инфраструктурный сервис и источник метрик через Redis Exporter.

Spring Cache в приложении отключён через:

```text
SPRING_CACHE_TYPE=none
```

Это сделано, чтобы учебный API не зависел от сериализации кэша и не ловил ложные 500 ошибки на простых REST-запросах.

## Ansible

Основные playbooks:

| Playbook | Назначение |
|---|---|
| `docker-up.yml` | Останавливает k3s и запускает Docker Compose стенд |
| `docker-down.yml` | Останавливает Docker Compose стенд |
| `k8s-up.yml` | Останавливает Docker Compose, запускает k3s и применяет manifests |
| `k8s-down.yml` | Останавливает k3s |
| `install-docker.yml` | Установка Docker |
| `install-k3s.yml` | Установка k3s |

Для локальной VM проще запускать playbooks через sudo:

```bash
sudo ansible-playbook playbooks/docker-up.yml
sudo ansible-playbook playbooks/k8s-up.yml
```

## Kubernetes resources

В namespace `perf-lab` создаются:

- Deployment `app` с двумя репликами;
- Service `app` типа NodePort;
- Deployment `postgres` + PVC;
- Deployment `redis` + PVC;
- exporters для PostgreSQL, Redis и Node;
- Prometheus Deployment + PVC + RBAC;
- Grafana Deployment + PVC + ConfigMaps;
- Ingress manifest как заготовка.

## GitLab CI

Pipeline содержит проверки:

- `terraform fmt`;
- `terraform validate`;
- Ansible syntax check;
- Kubernetes client dry-run;
- Maven build;
- Docker Compose config;
- Docker build/push;
- manual deploy to local Kubernetes runner.

## Типовые проблемы

### Docker зависает после Ctrl+C

На маленькой VM Docker daemon может подвисать после прерывания `docker compose up/down/build`.

Решение:

```bash
sudo systemctl restart docker
```

Если не помогло:

```bash
sudo reboot
```

### Одновременно запущены Docker Compose и k3s

Лучше не держать оба режима сразу.

Проверить k3s:

```bash
systemctl is-active k3s || true
```

Остановить:

```bash
sudo systemctl stop k3s
sudo /usr/local/bin/k3s-killall.sh
```

### Prometheus в Kubernetes не стартует из-за lock DB

Если старый Prometheus Pod держит PVC, новый Pod может падать с ошибкой lock DB.

Решение:

```bash
kubectl scale deployment/prometheus -n perf-lab --replicas=0
kubectl scale deployment/prometheus -n perf-lab --replicas=1
kubectl rollout status deployment/prometheus -n perf-lab --timeout=180s
```

В manifest используется strategy `Recreate`, чтобы не было двух Prometheus Pod'ов на одном PVC.

### Grafana не обновила dashboards

Docker режим:

```bash
docker compose stop grafana
docker compose rm -f grafana
docker volume rm java-performance-demo_grafana-data
docker compose up -d grafana
```

Kubernetes режим:

```bash
kubectl scale deployment/grafana -n perf-lab --replicas=0
kubectl delete pvc grafana-pvc -n perf-lab
kubectl apply -f k8s/grafana.yaml
kubectl apply -f k8s/grafana-dashboards.yaml
kubectl scale deployment/grafana -n perf-lab --replicas=1
```

## Что говорить на собеседовании

Короткое объяснение проекта:

> Я собрал production-like performance lab: Java Spring Boot приложение, PostgreSQL, Redis, Nginx, Prometheus, Grafana и exporters. Стенд можно запускать в двух режимах: Docker Compose для быстрой локальной проверки и Kubernetes/k3s для демонстрации manifests, PVC, probes, resources, ConfigMap, Secret и RBAC. Ansible переключает режимы и выполняет health checks. Метрики приложения идут через Spring Actuator Prometheus endpoint, инфраструктурные метрики — через exporters. Grafana dashboards provisioned из файлов, поэтому стенд воспроизводим после чистого запуска.

Что можно подчеркнуть:

- разделены Docker и Kubernetes режимы;
- приложение масштабируется до двух инстансов;
- Nginx балансирует Docker Compose инстансы;
- Kubernetes Service балансирует Pod'ы;
- Prometheus использует static targets в Docker и pod discovery в Kubernetes;
- Grafana не настраивается руками, dashboards и datasource приходят через provisioning;
- у stateful компонентов есть volumes/PVC;
- для Prometheus используется Recreate strategy из-за одного PVC;
- cAdvisor удалён как нестабильный источник Docker metadata на локальной VM, вместо него оставлены стабильные метрики приложения, БД, Redis и хоста.

## Быстрая финальная проверка

Docker:

```bash
cd ~/training/java-performance-demo/ansible
sudo ansible-playbook playbooks/docker-up.yml
curl http://localhost:8088/actuator/health
curl http://localhost:9090/-/ready
curl http://localhost:3000/api/health
```

Kubernetes:

```bash
cd ~/training/java-performance-demo/ansible
sudo ansible-playbook playbooks/k8s-up.yml
curl http://localhost:30080/actuator/health
curl http://localhost:30090/-/ready
curl http://localhost:30030/api/health
```

## Структура проекта

```text
app/                         Spring Boot приложение
ansible/                     Playbooks для Docker и Kubernetes режимов
docker-compose.yml           Docker Compose стенд
grafana/                     Provisioning и dashboards для Docker Grafana
k8s/                         Kubernetes manifests
nginx/                       Nginx reverse proxy для Docker Compose
postgres/                    init.sql для PostgreSQL
prometheus/                  Prometheus config для Docker Compose
terraform/                   IaC заготовка под Yandex Cloud
.gitlab-ci.yml               CI pipeline
README.md                    Документация проекта
```
