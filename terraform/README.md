Terraform cloud-ready слой
Эта папка содержит Terraform-структуру для будущего развёртывания проекта `java-performance-demo` в облаке.
Terraform отвечает за подготовку инфраструктуры:
сеть;
подсеть;
security group / firewall rules;
виртуальную машину;
boot disk;
public IP;
SSH-доступ.
Terraform не разворачивает Kubernetes manifests. Kubernetes-ресурсы остаются в папке `k8s/`, а Ansible отвечает за установку Docker/k3s и применение manifests.
---
Роль Terraform в проекте
Текущая локальная схема:
```text
VirtualBox VM
  -> Ansible
      -> Docker / k3s
      -> Kubernetes manifests
          -> Spring Boot app
          -> PostgreSQL
          -> Redis
          -> Prometheus
          -> Grafana
```
Cloud-ready схема:
```text
Terraform
  -> Cloud VM, network, subnet, security group, disk, public IP
  -> Ansible
      -> Docker / k3s installation
      -> Kubernetes manifests apply
          -> Spring Boot app
          -> PostgreSQL
          -> Redis
          -> Prometheus
          -> Grafana
```
Такое разделение сделано специально:
```text
Terraform   -> infrastructure
Ansible     -> server setup / automation
Kubernetes  -> application and monitoring stack
```
---
Что уже подготовлено
Первое окружение подготовлено под Yandex Cloud:
```text
terraform/environments/yandex
```
Структура:
```text
terraform/
├── README.md
├── environments/
│   └── yandex/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── terraform.tfvars.example
│       └── .gitignore
└── modules/
    └── compute-vm/
        ├── main.tf
        ├── variables.tf
        ├── versions.tf
        └── outputs.tf
```
---
Что создаёт Terraform
В текущей версии Terraform описывает:
```text
VPC network
Subnet
Security Group
Virtual Machine
Boot Disk
Public IP
SSH access
```
После создания VM Ansible может подключиться к ней по SSH и развернуть стенд.
---
Что Terraform не делает
Terraform не создаёт:
```text
Kubernetes Deployment
Kubernetes Service
Kubernetes ConfigMap
Kubernetes PVC
Grafana dashboards
Prometheus config
```
Эти ресурсы уже описаны в папке:
```text
k8s/
```
---
Проверка без покупки cloud
Можно проверить форматирование Terraform-кода без создания облачных ресурсов:
```bash
cd ~/training/java-performance-demo

terraform fmt -recursive
```
Если Terraform Registry или зеркало provider'ов доступны из текущей сети, можно также выполнить:
```bash
cd terraform/environments/yandex

terraform init
terraform validate
```
---
Установка Terraform CLI через зеркало Yandex Cloud
Если официальный `releases.hashicorp.com` скачивается медленно или недоступен, Terraform CLI можно скачать через зеркало Yandex Cloud.
Пример для Terraform `1.9.8`:
```bash
cd /tmp
curl -LO https://hashicorp-releases.yandexcloud.net/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip
unzip terraform_1.9.8_linux_amd64.zip
sudo mv terraform /usr/local/bin/
terraform version
```
Это устанавливает только сам бинарник `terraform`.
---
Настройка Terraform provider mirror
`terraform init` требует доступ к Terraform Registry, чтобы скачать provider:
```text
yandex-cloud/yandex
```
Если из текущей сети `registry.terraform.io` недоступен или блокируется по географии, `terraform init` может завершиться ошибкой.
Пример ошибки:
```text
Invalid provider registry host
x-amzn-waf-reason: geo
```
Это не ошибка Terraform-кода и не проблема проекта. В таком случае можно использовать зеркало Terraform providers от Yandex Cloud.
Создайте файл:
```bash
nano ~/.terraformrc
```
Добавьте в него:
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
После этого очистите неудачную инициализацию и запустите Terraform заново:
```bash
cd ~/training/java-performance-demo/terraform/environments/yandex

rm -rf .terraform .terraform.lock.hcl
terraform init -upgrade
terraform validate
```
Эта настройка не меняет Terraform-код проекта. Она только указывает Terraform CLI, откуда скачивать provider plugins, если основной Terraform Registry недоступен.
---
Подготовка к реальному запуску
Скопировать пример переменных:
```bash
cd ~/training/java-performance-demo/terraform/environments/yandex

cp terraform.tfvars.example terraform.tfvars
```
Заполнить реальные значения:
```hcl
cloud_id  = "your-yandex-cloud-id"
folder_id = "your-yandex-folder-id"
zone      = "ru-central1-a"

image_id = "your-ubuntu-image-id"
```
После этого можно выполнить:
```bash
terraform init
terraform plan
terraform apply
```
После `terraform apply` Terraform выведет:
```text
vm_public_ip
vm_internal_ip
vm_id
ssh_command
ansible_inventory_line
```
Пример:
```text
ssh_command = "ssh ubuntu@x.x.x.x"
```
Этот IP можно использовать в Ansible inventory.
---
Пример дальнейшего запуска Ansible
После создания VM через Terraform:
```bash
cd ~/training/java-performance-demo/ansible

ansible-playbook -i inventory.ini playbooks/install-docker.yml
ansible-playbook -i inventory.ini playbooks/install-k3s.yml
ansible-playbook -i inventory.ini playbooks/k8s-up.yml
```
---
Очистка ресурсов
Чтобы не платить за простаивающую инфраструктуру:
```bash
cd ~/training/java-performance-demo/terraform/environments/yandex

terraform destroy
```
---
Storage notes
В текущем локальном стенде данные хранятся через PVC внутри k3s.
Для production-like сценария:
```text
PostgreSQL live data  -> PVC / cloud disk
Prometheus TSDB       -> PVC / cloud disk
Grafana runtime data  -> PVC / cloud disk
```
S3/Object Storage не используется как live-volume для PostgreSQL или Prometheus.
S3/Object Storage можно добавить позже для:
```text
PostgreSQL backups
Prometheus long-term metrics через Thanos / Mimir / VictoriaMetrics
artifact storage
```
---
Текущий статус
Сейчас Terraform-слой добавлен как cloud-ready часть проекта.
Локальная лаборатория продолжает работать через:
```text
VirtualBox VM
Ansible
k3s
Kubernetes manifests
```
Cloud-сценарий можно будет включить позже, если понадобится реальное развёртывание в Yandex Cloud.
