output "public_ip" {
  description = "Public IP address."
  value       = yandex_compute_instance.vm.network_interface[0].nat_ip_address
}

output "internal_ip" {
  description = "Internal IP address."
  value       = yandex_compute_instance.vm.network_interface[0].ip_address
}

output "vm_id" {
  description = "Yandex Compute VM ID."
  value       = yandex_compute_instance.vm.id
}
