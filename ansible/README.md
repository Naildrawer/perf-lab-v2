# Ansible

Обычные playbook'и без лишнего debug-вывода.

## Playbooks

- `install-docker.yml` — установить Docker.
- `install-k3s.yml` — установить k3s.
- `docker-up.yml` — переключиться в Docker Compose режим.
- `docker-down.yml` — остановить Docker Compose режим.
- `k8s-up.yml` — переключиться в Kubernetes режим.
- `k8s-down.yml` — остановить Kubernetes режим.

## Запуск

```bash
cd ansible
ansible-playbook playbooks/docker-up.yml
```

```bash
cd ansible
ansible-playbook playbooks/k8s-up.yml
```

## Важно

Папка `ansible/` должна лежать в корне проекта:

```text
repo/
├── app/
├── docker-compose.yml
├── k8s/
├── prometheus/
├── grafana/
└── ansible/
```
