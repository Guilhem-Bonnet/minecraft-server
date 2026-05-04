# Minecraft Gaming Server — Proxmox LXC (provider bpg/proxmox)
#
# Phase 3 TRANSITION_PLAN F-03 : migration `telmate/proxmox` → `bpg/proxmox`.
# Module simple (resource directe, pas via lxc-docker-stack pour rester self-contained
# au repo minecraft-server). Provisioning Docker/packages délégué à Ansible.

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.98.1"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  insecure  = var.proxmox_insecure
  api_token = var.proxmox_api_token

  ssh {
    agent    = true
    username = var.proxmox_ssh_username
  }
}

# Conteneur LXC pour le serveur Minecraft (Docker inside)
resource "proxmox_virtual_environment_container" "gaming_server" {
  node_name = var.proxmox_node
  vm_id     = var.vmid

  description = <<-EOT
    Gaming Server — Minecraft (Paper) via Docker
    Géré par Terraform (provider bpg/proxmox)

    Services:
    - Minecraft (Paper) via Docker
    - Infrared (proxy scale-to-zero)
    - Backup automatique vers S3 (homelab-backups-guilhem-2025)

    Ports:
    - 25565: Minecraft
    - 8080: WebUI contrôle (interne)
  EOT
  tags        = var.tags

  started      = true
  unprivileged = true

  operating_system {
    template_file_id = var.os_template
    type             = "debian"
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory
    swap      = var.swap
  }

  # Disque rootfs
  disk {
    datastore_id = var.storage
    size         = var.disk_size_gb
  }

  # Mountpoint données (optionnel, séparation jeux)
  dynamic "mount_point" {
    for_each = var.data_storage != "" ? [1] : []
    content {
      volume = var.data_storage
      size   = "${var.data_disk_size_gb}G"
      path   = "/opt/games"
    }
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  initialization {
    hostname = var.hostname

    dns {
      servers = [var.nameserver]
    }

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    user_account {
      keys     = compact(split("\n", var.ssh_public_keys))
      password = var.root_password
    }
  }

  features {
    nesting = true
    keyctl  = true
  }

  start_on_boot = var.start_on_boot

  lifecycle {
    ignore_changes = [
      initialization[0].user_account,
      operating_system[0].template_file_id,
      started,
    ]

    # Désactivée car gaming-server pas encore en service (validation user 2026-05-04)
    prevent_destroy = false
  }
}
