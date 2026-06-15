# Java Performance Lab

Небольшой учебный проект для практики в performance engineering и мониторинге Java-приложения.

В проекте есть Spring Boot сервис, PostgreSQL, Redis, Nginx, Prometheus, Grafana и exporters. Один и тот же стенд можно запустить двумя способами:

* через Docker Compose;
* через Kubernetes/k3s.

Идея проекта — посмотреть, как приложение ведёт себя в разных окружениях, как собираются метрики и как их можно анализировать в Grafana.

\---

## Что есть в проекте

* Spring Boot приложение с endpoint `/users`;
* PostgreSQL с тестовой таблицей `users`;
* Redis для cache;
* Nginx как балансировщик между двумя инстансами приложения;
* Prometheus для сбора метрик;
* Grafana для дашбордов;
* postgres-exporter;
* redis-exporter;
* node-exporter;
* cAdvisor;
* Kubernetes manifests для запуска в k3s.

\---

## Архитектура Docker Compose

В Docker Compose поднимается весь стенд одной командой.

Состав:

* `nginx` — принимает запросы снаружи;
* `spring-app` — первый инстанс приложения;
* `spring-app-2` — второй инстанс приложения;
* `postgres` — база данных;
* `redis` — cache;
* `prometheus` — сбор метрик;
* `grafana` — визуализация;
* `cadvisor` — метрики контейнеров;
* `node-exporter` — метрики хоста;
* `postgres-exporter` — метрики PostgreSQL;
* `redis-exporter` — метрики Redis.

Снаружи приложение открывается через Nginx:

```bash
http://localhost/users
```

Grafana:

```bash
http://localhost:3000
```

Prometheus:

```bash
http://localhost:9090
```

\---

## Запуск через Docker Compose

```bash
cd \~/training/performance-lab

sudo docker compose up -d --build
```

Проверить контейнеры:

```bash
docker ps
```

Проверить приложение:

```bash
curl http://localhost/users
```

Остановить Docker-стенд:

```bash
sudo docker compose down
```

\---

## Архитектура Kubernetes/k3s

Во второй части проекта тот же стенд перенесён в Kubernetes.

В Kubernetes используются:

* `Namespace`;
* `Deployment`;
* `Service`;
* `NodePort`;
* `Ingress`;
* `ConfigMap`;
* `PVC`;
* `RBAC`;
* `DaemonSet`.

Основные сервисы:

* Spring Boot приложение — 2 pod’а;
* PostgreSQL;
* Redis;
* Prometheus;
* Grafana;
* exporters.

Внешние порты:

|Сервис|Порт|
|-|-|
|Spring Boot|`30080`|
|Grafana|`30030`|
|Prometheus|`30090`|

Проверить приложение в Kubernetes:

```bash
curl http://localhost:30080/users
```

Grafana:

```bash
http://localhost:30030
```

Prometheus:

```bash
http://localhost:30090
```

\---

## Запуск Kubernetes-стенда

```bash
cd \~/training/java-performance-demo

kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/redis.yaml
kubectl apply -f k8s/app.yaml
kubectl apply -f k8s/postgres-exporter.yaml
kubectl apply -f k8s/redis-exporter.yaml
kubectl apply -f k8s/node-exporter.yaml
kubectl apply -f k8s/cadvisor.yaml
kubectl apply -f k8s/prometheus-rbac-service-view.yaml
```

Обновить конфиг Prometheus:

```bash
kubectl create configmap prometheus-config -n perf-lab \\
  --from-file=prometheus.yml=prometheus/prometheus-k8s.yml \\
  --dry-run=client -o yaml | kubectl apply -f -
```

Запустить Prometheus и Grafana:

```bash
kubectl apply -f k8s/prometheus.yaml
kubectl apply -f k8s/grafana.yaml
```

Проверить pod’ы:

```bash
kubectl get pods -n perf-lab
```

\---

## Как переключаться между Docker и Kubernetes

Я не запускаю Docker Compose и Kubernetes одновременно, чтобы не ловить конфликты портов.

### Перейти в Docker-режим

```bash
sudo systemctl stop k3s
sudo /usr/local/bin/k3s-killall.sh

cd \~/training/performance-lab
sudo docker compose up -d --build
```

### Вернуться в Kubernetes-режим

```bash
cd \~/training/performance-lab
sudo docker compose down

sudo systemctl start k3s
sleep 40

kubectl get pods -n perf-lab
```

\---

## Метрики

Prometheus собирает:

* HTTP-метрики Spring Boot;
* JVM memory;
* JVM threads;
* GC;
* PostgreSQL metrics;
* Redis metrics;
* container metrics;
* host metrics.

Для Spring Boot используется endpoint:

```bash
/actuator/prometheus
```

В Docker Compose Prometheus ходит к:

```text
app:8080
app2:8080
```

В Kubernetes используется discovery pod’ов через Prometheus config.

\---

## Дашборды Grafana

В проекте есть отдельные дашборды для Docker Compose и Kubernetes.

Docker dashboard лучше открывать в Docker Grafana:

```bash
http://localhost:3000
```

Kubernetes dashboard лучше открывать в Kubernetes Grafana:

```bash
http://localhost:30030
```

Важно не смешивать Docker dashboard с Kubernetes Prometheus и наоборот, потому что там разные labels и targets.

\---

## Простая нагрузка

Docker:

```bash
for i in {1..100}; do
  curl -s http://localhost/users > /dev/null
done
```

Kubernetes:

```bash
for i in {1..100}; do
  curl -s http://localhost:30080/users > /dev/null
done
```

После этого можно смотреть изменения в Grafana.

\---

## Полезные команды

Docker:

```bash
docker ps
docker logs spring-app --tail=100
docker logs prometheus --tail=100
docker logs grafana --tail=100
```

Kubernetes:

```bash
kubectl get pods -n perf-lab
kubectl get svc -n perf-lab
kubectl logs -n perf-lab deployment/app --tail=100
kubectl logs -n perf-lab deployment/prometheus --tail=100
kubectl logs -n perf-lab deployment/grafana --tail=100
```

Проверить занятые порты:

```bash
sudo ss -ltnp | egrep ':80|:8080|:8081|:9090|:3000|:30080|:30030|:30090|:9100'
```

\---

## Что я отработал в этом проекте

* запуск Java-приложения в Docker Compose;
* перенос приложения в Kubernetes/k3s;
* настройку Nginx load balancing;
* подключение PostgreSQL и Redis;
* настройку Prometheus;
* настройку Grafana dashboards;
* работу с exporters;
* настройку Kubernetes Services, Deployments, PVC, ConfigMap и RBAC;
* диагностику портов, targets, labels и PromQL-запросов;
* сравнение Docker Compose и Kubernetes окружений.

\---

## 

