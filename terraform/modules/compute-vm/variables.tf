variable "vm_name" {
  description = "Virtual machine name."
  type        = string
}

variable "platform_id" {
  description = "Yandex Compute platform ID."
  type        = string
}

variable "zone" {
  description = "Yandex Cloud availability zone."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for VM network interface."
  type        = string
}

variable "security_group_ids" {
  description = "Security group IDs attached to the VM."
  type        = list(string)
}

variable "image_id" {
  description = "OS image ID."
  type        = string
}

variable "disk_type" {
  description = "Boot disk type."
  type        = string
}

variable "disk_size" {
  description = "Boot disk size in GB."
  type        = number
}

variable "cores" {
  description = "Number of vCPU cores."
  type        = number
}

variable "memory" {
  description = "RAM size in GB."
  type        = number
}

variable "ssh_user" {
  description = "SSH username."
  type        = string
}

variable "ssh_public_key" {
  description = "Public SSH key content."
  type        = string
  sensitive   = true
}

variable "labels" {
  description = "Labels applied to the VM."
  type        = map(string)
  default     = {}
}
