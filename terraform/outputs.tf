# Outputs — Gaming Server (provider bpg/proxmox)

output "container_id" {
  description = "ID du container LXC"
  value       = proxmox_virtual_environment_container.gaming_server.vm_id
}

output "container_hostname" {
  description = "Hostname du container"
  value       = var.hostname
}

output "container_ip" {
  description = "Adresse IP du container"
  value       = var.ip_address
}

output "ansible_host" {
  description = "Ligne pour l'inventaire Ansible"
  value       = "${var.hostname} ansible_host=${split("/", var.ip_address)[0]}"
}

output "ssh_connection" {
  description = "Commande SSH pour se connecter"
  value       = "ssh root@${split("/", var.ip_address)[0]}"
}
