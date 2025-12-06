# Variables pour le module Gaming Server

# Proxmox
variable "proxmox_node" {
  description = "Nom du node Proxmox"
  type        = string
  default     = "developadream"
}

# LXC Configuration
variable "hostname" {
  description = "Hostname du container"
  type        = string
  default     = "gaming-server"
}

variable "vmid" {
  description = "ID du container LXC"
  type        = number
  default     = 120
}

variable "os_template" {
  description = "Template OS pour le LXC"
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"
}

# Ressources
variable "cores" {
  description = "Nombre de CPU cores"
  type        = number
  default     = 4
}

variable "memory" {
  description = "Mémoire RAM en MB"
  type        = number
  default     = 8192  # 8GB pour Minecraft
}

variable "swap" {
  description = "Swap en MB"
  type        = number
  default     = 2048
}

# Stockage
variable "storage" {
  description = "Pool de stockage pour le rootfs"
  type        = string
  default     = "local-lvm"
}

variable "disk_size" {
  description = "Taille du disque root"
  type        = string
  default     = "30G"
}

variable "data_storage" {
  description = "Pool de stockage pour les données de jeux (optionnel)"
  type        = string
  default     = ""
}

variable "data_disk_size" {
  description = "Taille du disque de données"
  type        = string
  default     = "50G"
}

# Réseau
variable "network_bridge" {
  description = "Bridge réseau"
  type        = string
  default     = "vmbr0"
}

variable "ip_address" {
  description = "Adresse IP statique (CIDR)"
  type        = string
  default     = "192.168.2.70/24"
}

variable "gateway" {
  description = "Gateway"
  type        = string
  default     = "192.168.2.1"
}

# Démarrage
variable "start_on_boot" {
  description = "Démarrer au boot de Proxmox"
  type        = bool
  default     = false  # Non par défaut car scale-to-zero
}

variable "protection" {
  description = "Protection contre suppression"
  type        = bool
  default     = true
}

# Sécurité
variable "root_password" {
  description = "Mot de passe root initial"
  type        = string
  sensitive   = true
}

variable "ssh_public_keys" {
  description = "Clés SSH publiques autorisées"
  type        = string
  default     = ""
}

# Tags
variable "tags" {
  description = "Tags pour le container"
  type        = list(string)
  default     = ["gaming", "minecraft", "docker", "terraform"]
}
