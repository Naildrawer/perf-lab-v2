variable "cloud_id" {
  description = "Yandex Cloud ID."
  type        = string
}

variable "folder_id" {
  description = "Yandex Cloud Folder ID."
  type        = string
}

variable "zone" {
  description = "Yandex Cloud availability zone."
  type        = string
  default     = "ru-central1-a"
}

variable "network_name" {
  description = "VPC network name."
  type        = string
  default     = "java-performance-network"
}

variable "subnet_name" {
  description = "VPC subnet name."
  type        = string
  default     = "java-performance-subnet"
}

variable "subnet_cidr_blocks" {
  description = "CIDR blocks for the subnet."
  type        = list(string)
  default     = ["10.10.0.0/24"]
}

variable "security_group_name" {
  description = "Security group name."
  type        = string
  default     = "java-performance-security-group"
}

variable "allowed_ssh_cidr_blocks" {
  description = "CIDR blocks allowed to connect over SSH. For real usage, restrict this to your public IP."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_app_cidr_blocks" {
  description = "CIDR blocks allowed to access the application NodePort."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_grafana_cidr_blocks" {
  description = "CIDR blocks allowed to access Grafana NodePort."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_prometheus_cidr_blocks" {
  description = "CIDR blocks allowed to access Prometheus NodePort."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "vm_name" {
  description = "Virtual machine name."
  type        = string
  default     = "java-performance-demo"
}

variable "platform_id" {
  description = "Yandex Compute platform ID."
  type        = string
  default     = "standard-v3"
}

variable "image_id" {
  description = "OS image ID. Use an Ubuntu image ID from Yandex Cloud."
  type        = string
}

variable "disk_type" {
  description = "Boot disk type."
  type        = string
  default     = "network-ssd"
}

variable "disk_size" {
  description = "Boot disk size in GB."
  type        = number
  default     = 50
}

variable "cores" {
  description = "Number of vCPU cores."
  type        = number
  default     = 4
}

variable "memory" {
  description = "RAM size in GB."
  type        = number
  default     = 8
}

variable "ssh_user" {
  description = "SSH username created through cloud-init metadata."
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key_path" {
  description = "Path to public SSH key."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "labels" {
  description = "Labels applied to the VM."
  type        = map(string)
  default = {
    project = "java-performance-demo"
    owner   = "training"
  }
}
