# Java Performance Demo

Учебный production-like проект для практики в **performance engineering**, мониторинге, Kubernetes, Ansible, Terraform и GitLab CI/CD.

Проект показывает, как одно Spring Boot приложение можно запускать в двух режимах:

* локально через **Docker Compose**;
* в Kubernetes через **k3s**.

Вокруг приложения собран observability-стенд: **Prometheus, Grafana, PostgreSQL exporter, Redis exporter, node-exporter, cAdvisor**. Инфраструктура и запуск описаны через **Docker Compose**, **Kubernetes manifests**, **Ansible**, **Terraform cloud-ready слой** и **GitLab CI/CD**.

\---

## Цель проекта

Цель проекта — собрать воспроизводимый стенд, который демонстрирует практические навыки:

* контейнеризация Java-приложения;
* запуск приложения в Docker Compose и Kubernetes;
* работа с PostgreSQL и Redis;
* сбор JVM, HTTP, container, node, PostgreSQL и Redis метрик;
* настройка Prometheus и Grafana;
* provisioning Grafana datasource и dashboards из Git;
* Kubernetes manifests и persistence через PVC;
* автоматизация запуска через Ansible;
* cloud-ready инфраструктурный слой через Terraform;
* GitLab CI/CD pipeline с build, Docker image push и controlled manual deploy в k3s.

\---

## Что реализовано

* Spring Boot приложение с endpoint'ом `/users`.
* PostgreSQL как основная база данных.
* Redis для cache layer.
* Docker Compose режим с двумя инстансами приложения за Nginx.
* Kubernetes/k3s режим с Deployment, Service, NodePort и PVC.
* Prometheus для сбора метрик.
* Grafana с provisioned datasource и dashboards.
* Экспортёры:

  * postgres-exporter;
  * redis-exporter;
  * node-exporter;
  * cAdvisor.
* Ansible playbooks для запуска и остановки Docker Compose и Kubernetes режимов.
* Terraform skeleton для будущего развёртывания VM в Yandex Cloud.
* GitLab CI pipeline:

  * Terraform fmt/validate;
  * Ansible syntax check;
  * Maven build;
  * Docker image build и push в GitLab Container Registry;
  * Docker Compose config validation;
  * manual deploy в локальный k3s через self-hosted GitLab Runner.

\---

## Технологический стек

### Application

* Java 17
* Spring Boot
* Spring Web
* Spring Data JDBC
* Spring Cache
* Spring Actuator
* Micrometer Prometheus Registry
* PostgreSQL
* Redis

### Infrastructure

* Docker
* Docker Compose
* Nginx
* Kubernetes / k3s
* Ansible
* Terraform
* GitLab CI/CD

### Monitoring

* Prometheus
* Grafana
* postgres-exporter
* redis-exporter
* node-exporter
* cAdvisor
* kubelet/cAdvisor metrics

\---

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
  -> Kubernetes service/pod discovery
  -> Spring Boot /actuator/prometheus
  -> PostgreSQL exporter
  -> Redis exporter
  -> node-exporter
  -> cAdvisor
  -> kubelet/cAdvisor metrics

Grafana
  -> Prometheus datasource
  -> provisioned dashboards
```

\---

## Endpoint'ы

### Docker Compose

|Сервис|URL|
|-|-|
|Application|`http://localhost/users`|
|Grafana|`http://localhost:3000`|
|Prometheus|`http://localhost:9090`|

### Kubernetes/k3s

|Сервис|URL|
|-|-|
|Application|`http://localhost:30080/users`|
|Grafana|`http://localhost:30030`|
|Prometheus|`http://localhost:30090`|

Grafana credentials для lab:

```text
login: admin
password: admin
```

\---

## Структура проекта

```text
.
├── app/                         # Spring Boot приложение
├── ansible/                     # Ansible playbooks
│   ├── ansible.cfg
│   ├── inventory.ini
│   └── playbooks/
├── docker-compose.yml           # Docker Compose стенд
├── grafana/
│   ├── dashboards/              # JSON dashboards
│   └── provisioning/            # Grafana provisioning для Docker Compose
├── k8s/                         # Kubernetes manifests
├── nginx/                       # Nginx config для Docker Compose
├── postgres/                    # init.sql
├── prometheus/                  # Prometheus configs
└── terraform/                   # cloud-ready Terraform layer
```

\---

## Быстрый старт: Docker Compose

### Запуск

```bash
cd \~/training/java-performance-demo
sudo docker compose up -d --build
```

### Проверка

```bash
curl http://localhost/users
curl http://localhost:9090/-/ready
curl -I http://localhost:3000
```

### Остановка

```bash
sudo docker compose down
```

\---

## Быстрый старт: Kubernetes/k3s

Перед запуском Kubernetes режима Docker Compose лучше остановить:

```bash
cd \~/training/java-performance-demo
sudo docker compose down
```

Запуск через Ansible:

```bash
cd \~/training/java-performance-demo/ansible
ansible-playbook playbooks/k8s-up.yml
```

Проверка:

```bash
kubectl get pods -n perf-lab
kubectl get svc -n perf-lab
kubectl get pvc -n perf-lab
curl http://localhost:30080/users
```

Остановка Kubernetes режима:

```bash
cd \~/training/java-performance-demo/ansible
ansible-playbook playbooks/k8s-down.yml
```

\---

## Переключение режимов

### Перейти из Kubernetes в Docker Compose

```bash
sudo systemctl stop k3s
sudo /usr/local/bin/k3s-killall.sh

cd \~/training/java-performance-demo
sudo docker compose up -d --build
```

### Перейти из Docker Compose в Kubernetes

```bash
cd \~/training/java-performance-demo
sudo docker compose down

sudo systemctl start k3s
sleep 40

kubectl get pods -n perf-lab
```

После этого можно запустить Ansible playbook:

```bash
cd \~/training/java-performance-demo/ansible
ansible-playbook playbooks/k8s-up.yml
```

\---

## Ansible

Ansible используется для воспроизводимого запуска стенда.

### Docker Compose

```bash
cd \~/training/java-performance-demo/ansible
ansible-playbook playbooks/docker-up.yml
ansible-playbook playbooks/docker-down.yml
```

### Kubernetes/k3s

```bash
cd \~/training/java-performance-demo/ansible
ansible-playbook playbooks/k8s-up.yml
ansible-playbook playbooks/k8s-down.yml
```

### Установка базовых компонентов

```bash
cd \~/training/java-performance-demo/ansible
ansible-playbook playbooks/install-docker.yml
ansible-playbook playbooks/install-k3s.yml
```

`k8s-up.yml` дополнительно собирает Docker image приложения, импортирует его в k3s containerd и применяет Kubernetes manifests.

\---

## Kubernetes manifests

Kubernetes resources находятся в директории `k8s/`.

Основные компоненты:

* `namespace.yaml` — namespace `perf-lab`;
* `app.yaml` — Spring Boot Deployment и Services;
* `postgres.yaml` — PostgreSQL + PVC;
* `redis.yaml` — Redis;
* `prometheus-config.yaml` — Prometheus config через ConfigMap;
* `prometheus.yaml` — Prometheus Deployment, Service и PVC;
* `grafana-datasources.yaml` — Grafana datasource provisioning;
* `grafana-dashboard-providers.yaml` — Grafana dashboard provider;
* `grafana-dashboards.yaml` — Grafana dashboards через ConfigMap;
* `grafana.yaml` — Grafana Deployment, Service и PVC;
* `cadvisor.yaml` — cAdvisor DaemonSet;
* `node-exporter.yaml` — node-exporter DaemonSet;
* `postgres-exporter.yaml` — PostgreSQL exporter;
* `redis-exporter.yaml` — Redis exporter;
* `ingress.yaml` — Ingress manifest.

\---

## Grafana и dashboards

Dashboards хранятся в Git:

```text
grafana/dashboards/Java Performance Docker Compose.json
grafana/dashboards/Java Performance Kubernetes.json
```

В Docker Compose режиме Grafana читает provisioning из директории `grafana/provisioning`.

В Kubernetes режиме datasource и dashboards создаются через ConfigMap:

```text
k8s/grafana-datasources.yaml
k8s/grafana-dashboard-providers.yaml
k8s/grafana-dashboards.yaml
```

Если dashboard меняется через UI Grafana, его нужно экспортировать в JSON и закоммитить в репозиторий. Иначе при переносе на новую VM изменения не будут восстановлены из Git.

\---

## Prometheus

### Docker Compose config

```text
prometheus/prometheus.yml
```

### Kubernetes config

```text
k8s/prometheus-config.yaml
prometheus/prometheus-k8s.yml
prometheus/prometheus-k8s-service-view.yml
```

Prometheus собирает метрики приложения, PostgreSQL, Redis, node-exporter, cAdvisor и Kubernetes/container metrics.

\---

## Terraform

Terraform находится в директории `terraform/` и описывает cloud-ready инфраструктурный слой для Yandex Cloud.

Структура:

```text
terraform/
├── README.md
├── environments/
│   └── yandex/
└── modules/
    └── compute-vm/
```

Проверка локально:

```bash
cd terraform/environments/yandex
terraform init -backend=false
terraform validate
terraform fmt -recursive
```

В текущей версии Terraform используется для демонстрации IaC-подхода и проверки конфигурации в CI. Реальное создание cloud-ресурсов через `terraform apply` не выполняется.

\---

## GitLab CI/CD

Pipeline описан в `.gitlab-ci.yml`.

Основные стадии:

```text
validate -> build -> docker -> deploy
```

Jobs:

* `terraform:fmt` — проверка форматирования Terraform;
* `terraform:validate` — проверка Terraform-конфигурации;
* `ansible:syntax` — syntax check Ansible playbooks;
* `spring:build` — Maven build Spring Boot приложения;
* `docker:build:push` — сборка Docker image и push в GitLab Container Registry;
* `docker:compose:config` — проверка Docker Compose config;
* `deploy:k8s` — ручной deploy нового image в локальный k3s.

### Почему deploy ручной

`deploy:k8s` сделан manual job специально. Это controlled deploy: pipeline автоматически проверяет проект и собирает image, но изменение работающего k3s-стенда выполняется только после ручного подтверждения.

Такой подход безопаснее для production-like стенда: каждый push не перезапускает приложение автоматически.

### Что делает deploy job

Manual deploy:

1. использует self-hosted GitLab Runner с tag `local-deploy`;
2. подключается к локальному k3s через kubeconfig;
3. создаёт/обновляет Kubernetes secret для GitLab Registry;
4. подключает `imagePullSecrets` к default service account;
5. обновляет image в `deployment/app`;
6. ждёт успешного rollout;
7. показывает app pods.

\---

## GitLab Registry deploy token

Для deploy в k3s нужен GitLab Deploy Token со scope:

```text
read\_registry
```

В CI/CD variables должны быть заданы:

```text
REGISTRY\_DEPLOY\_USER
REGISTRY\_DEPLOY\_PASSWORD
```

Рекомендации:

* `REGISTRY\_DEPLOY\_PASSWORD` должен быть masked;
* `Protected` нужно выключить, если ветка `perf-lab-dev` не protected;
* token должен быть создан для того проекта, из registry которого Kubernetes скачивает image.

\---

## Self-hosted GitLab Runner

Для manual deploy используется локальный GitLab Runner на VM с k3s.

Runner должен иметь tag:

```text
local-deploy
```

Executor:

```text
shell
```

Kubeconfig для пользователя `gitlab-runner`:

```text
/home/gitlab-runner/.kube/config
```

Проверка доступа:

```bash
sudo -u gitlab-runner KUBECONFIG=/home/gitlab-runner/.kube/config kubectl get pods -n perf-lab
```

\---

## Проверка после deploy

После запуска manual job `deploy:k8s`:

```bash
kubectl rollout status deployment/app -n perf-lab
kubectl get pods -n perf-lab -l app=spring -o wide
kubectl describe deployment app -n perf-lab | grep Image
curl http://localhost:30080/users
```

Если image в Deployment указывает на GitLab Registry, значит deploy работает корректно:

```text
registry.gitlab.com/<group>/<project>/app:<commit\_sha>
```

\---

## Полезные команды диагностики

### Kubernetes events

```bash
kubectl get events -n perf-lab --sort-by='.lastTimestamp' | tail -50
```

### Проверить image в Deployment

```bash
kubectl get deployment app -n perf-lab -o jsonpath='{.spec.template.spec.containers\[0].image}'
echo
```

### Проверить imagePullPolicy

```bash
kubectl get deployment app -n perf-lab -o jsonpath='{.spec.template.spec.containers\[0].imagePullPolicy}'
echo
```

### Проверить Registry secret

```bash
kubectl get secret gitlab-registry -n perf-lab
kubectl get serviceaccount default -n perf-lab -o yaml
```

### Откатить rollout

```bash
kubectl rollout undo deployment/app -n perf-lab
kubectl rollout status deployment/app -n perf-lab
```

\---

## Примечания по persistence

В Kubernetes режиме используются PVC для:

* PostgreSQL data;
* Prometheus data;
* Grafana runtime data.

Git-managed конфигурация Grafana и Prometheus восстанавливается из репозитория. Runtime-состояние Grafana, например ручные UI-изменения, пользователи, сессии и API keys, не является частью Git-managed provisioning.

\---

## Итог

Проект демонстрирует полный путь от Java-приложения до production-like стенда:

```text
Spring Boot
  -> Docker image
  -> Docker Compose / Kubernetes
  -> PostgreSQL + Redis
  -> Prometheus metrics
  -> Grafana dashboards
  -> Ansible automation
  -> Terraform IaC skeleton
  -> GitLab CI/CD
  -> manual deploy to k3s
```

Это учебный, но близкий к реальной практике стенд для демонстрации DevOps / Performance Engineering навыков.

