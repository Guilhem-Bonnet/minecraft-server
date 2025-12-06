# Minecraft Gaming Server - Proxmox LXC
# 
# Ce module crée un LXC optimisé pour le gaming avec:
# - Ressources dédiées (pas de ballooning)
# - Nesting pour Docker
# - Stockage SSD pour performance

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 3.0"
    }
  }
}

# LXC Container pour le serveur de gaming
resource "proxmox_lxc" "gaming_server" {
  target_node  = var.proxmox_node
  hostname     = var.hostname
  vmid         = var.vmid
  
  # Template Debian 12 (recommandé pour Docker)
  ostemplate   = var.os_template
  
  # Ressources - Dimensionnées pour gaming
  cores        = var.cores
  memory       = var.memory
  swap         = var.swap
  
  # Stockage principal
  rootfs {
    storage = var.storage
    size    = var.disk_size
  }
  
  # Stockage dédié données jeux (optionnel, pour séparation)
  dynamic "mountpoint" {
    for_each = var.data_storage != "" ? [1] : []
    content {
      key     = "0"
      slot    = 0
      storage = var.data_storage
      size    = var.data_disk_size
      mp      = "/opt/games"
    }
  }
  
  # Réseau
  network {
    name   = "eth0"
    bridge = var.network_bridge
    ip     = var.ip_address
    gw     = var.gateway
  }
  
  # Features nécessaires pour Docker
  features {
    nesting = true
    keyctl  = true
  }
  
  # Options de démarrage
  onboot      = var.start_on_boot
  start       = true
  unprivileged = true
  
  # Protection contre suppression accidentelle
  protection  = var.protection
  
  # Password root (à changer via Ansible ensuite)
  password    = var.root_password
  
  # SSH keys pour accès
  ssh_public_keys = var.ssh_public_keys
  
  # Tags pour organisation
  tags = join(";", var.tags)
  
  # Description
  description = <<-EOT
    Gaming Server - Minecraft et autres
    Géré par Terraform
    
    Services:
    - Minecraft (Paper) via Docker
    - Infrared (proxy scale-to-zero)
    - Backup automatique vers S3
    
    Ports:
    - 25565: Minecraft
    - 8080: WebUI contrôle (interne)
  EOT
  
  lifecycle {
    ignore_changes = [
      # Ignorer les changements de password après création
      password,
    ]
  }
}

# Output pour Ansible inventory
output "gaming_server" {
  value = {
    id       = proxmox_lxc.gaming_server.vmid
    hostname = proxmox_lxc.gaming_server.hostname
    ip       = var.ip_address
    node     = var.proxmox_node
  }
  description = "Gaming server details for Ansible inventory"
}
