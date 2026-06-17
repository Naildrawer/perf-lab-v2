output "vm_public_ip" {
  description = "Public IP address of the VM."
  value       = module.perf_lab_vm.public_ip
}

output "vm_internal_ip" {
  description = "Internal IP address of the VM."
  value       = module.perf_lab_vm.internal_ip
}

output "vm_id" {
  description = "Yandex Compute VM ID."
  value       = module.perf_lab_vm.vm_id
}

output "ssh_command" {
  description = "SSH command for manual connection."
  value       = "ssh ${var.ssh_user}@${module.perf_lab_vm.public_ip}"
}

output "ansible_inventory_line" {
  description = "Inventory line for Ansible."
  value       = "${module.perf_lab_vm.public_ip} ansible_user=${var.ssh_user}"
}
