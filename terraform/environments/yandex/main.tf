terraform {
  required_version = ">= 1.6.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.130"
    }
  }
}

provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}

resource "yandex_vpc_network" "perf_lab" {
  name = var.network_name
}

resource "yandex_vpc_subnet" "perf_lab" {
  name           = var.subnet_name
  zone           = var.zone
  network_id     = yandex_vpc_network.perf_lab.id
  v4_cidr_blocks = var.subnet_cidr_blocks
}

resource "yandex_vpc_security_group" "perf_lab" {
  name       = var.security_group_name
  network_id = yandex_vpc_network.perf_lab.id

  ingress {
    description    = "SSH"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = var.allowed_ssh_cidr_blocks
  }

  ingress {
    description    = "Application NodePort"
    protocol       = "TCP"
    port           = 30080
    v4_cidr_blocks = var.allowed_app_cidr_blocks
  }

  ingress {
    description    = "Grafana NodePort"
    protocol       = "TCP"
    port           = 30030
    v4_cidr_blocks = var.allowed_grafana_cidr_blocks
  }

  ingress {
    description    = "Prometheus NodePort"
    protocol       = "TCP"
    port           = 30090
    v4_cidr_blocks = var.allowed_prometheus_cidr_blocks
  }

  egress {
    description    = "Allow all outbound traffic"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

module "perf_lab_vm" {
  source = "../../modules/compute-vm"

  providers = {
    yandex = yandex
  }

  vm_name            = var.vm_name
  zone               = var.zone
  platform_id        = var.platform_id
  subnet_id          = yandex_vpc_subnet.perf_lab.id
  security_group_ids = [yandex_vpc_security_group.perf_lab.id]

  image_id  = var.image_id
  disk_type = var.disk_type
  disk_size = var.disk_size

  cores  = var.cores
  memory = var.memory

  ssh_user       = var.ssh_user
  ssh_public_key = file(var.ssh_public_key_path)

  labels = var.labels
}
