# Variables — Gaming Server (Minecraft) provider bpg/proxmox

# --------------------------------------------------------------------------
# Proxmox provider auth
# --------------------------------------------------------------------------
variable "proxmox_endpoint" {
  description = "URL de l'API Proxmox VE"
  type        = string
  default     = "https://192.168.2.22:8006/"
}

variable "proxmox_insecure" {
  description = "Skip TLS verification (cert auto-signé Proxmox). À désactiver une fois TLS valide (Phase 4 TRANSITION)."
  type        = bool
  default     = true
}

variable "proxmox_api_token" {
  description = "Token API Proxmox au format user@realm!tokenid=secret"
  type        = string
  sensitive   = true
}

variable "proxmox_ssh_username" {
  description = "Username SSH Proxmox (pour upload templates / pct exec)"
  type        = string
  default     = "root"
}

# --------------------------------------------------------------------------
# Placement Proxmox
# --------------------------------------------------------------------------
variable "proxmox_node" {
  description = "Nom du node Proxmox"
  type        = string
  default     = "developadream"
}

variable "vmid" {
  description = "ID du container LXC"
  type        = number
  default     = 120
}

variable "hostname" {
  description = "Hostname du container"
  type        = string
  default     = "gaming-server"
}

variable "os_template" {
  description = "Template OS pour le LXC (template_file_id bpg)"
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
}

# --------------------------------------------------------------------------
# Ressources LXC
# --------------------------------------------------------------------------
variable "cores" {
  description = "Nombre de CPU cores"
  type        = number
  default     = 4
}

variable "memory" {
  description = "Mémoire RAM en MB (Minecraft Paper recommande 6 GB JVM + overhead)"
  type        = number
  default     = 8192
}

variable "swap" {
  description = "Swap en MB"
  type        = number
  default     = 2048
}

# --------------------------------------------------------------------------
# Stockage
# --------------------------------------------------------------------------
variable "storage" {
  description = "Pool de stockage pour le rootfs (datastore_id bpg)"
  type        = string
  default     = "local-lvm"
}

variable "disk_size_gb" {
  description = "Taille du disque root en GB (entier, exigence bpg)"
  type        = number
  default     = 30
}

variable "data_storage" {
  description = "Pool de stockage pour les données de jeux (optionnel, '' désactive le mountpoint)"
  type        = string
  default     = ""
}

variable "data_disk_size_gb" {
  description = "Taille du disque de données en GB"
  type        = number
  default     = 50
}

# --------------------------------------------------------------------------
# Réseau
# --------------------------------------------------------------------------
variable "network_bridge" {
  description = "Bridge réseau"
  type        = string
  default     = "vmbr0"
}

variable "ip_address" {
  description = "Adresse IP statique (CIDR)"
  type        = string
  default     = "192.168.2.79/24"
}

variable "gateway" {
  description = "Gateway"
  type        = string
  default     = "192.168.2.1"
}

variable "nameserver" {
  description = "Serveur DNS du LXC"
  type        = string
  default     = "192.168.2.1"
}

# --------------------------------------------------------------------------
# Boot / Sécurité / Tags
# --------------------------------------------------------------------------
variable "start_on_boot" {
  description = "Démarrer au boot de Proxmox (false = scale-to-zero via Infrared)"
  type        = bool
  default     = false
}

variable "root_password" {
  description = "Mot de passe root initial (à changer via Ansible ensuite)"
  type        = string
  sensitive   = true
}

variable "ssh_public_keys" {
  description = "Clés SSH publiques autorisées, une par ligne"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags pour le container"
  type        = list(string)
  default     = ["gaming", "minecraft", "docker", "terraform"]
}
