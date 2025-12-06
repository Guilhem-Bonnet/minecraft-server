# 🎮 Minecraft Server Infrastructure

Infrastructure as Code complète pour déployer et gérer un serveur Minecraft optimisé avec :

- 🚀 **Scale-to-Zero** : Démarrage automatique à la connexion des joueurs
- 💾 **Backups S3 intelligents** : Sauvegarde dédupliquée avec restic
- 📦 **Distribution de mods** : Packwiz pour mise à jour automatique des mods
- �� **Monitoring Prometheus** : Métriques TPS, joueurs, mémoire
- 🐳 **Docker** : Déploiement conteneurisé avec Paper MC
- 🔧 **IaC** : Terraform + Ansible pour provisionnement et configuration

## 📋 Prérequis

- **Proxmox VE** >= 7.0
- **Terraform** >= 1.6
- **Ansible** >= 2.15
- **Docker** & Docker Compose
- Stockage **S3** compatible (MinIO, AWS S3, etc.)

## 🏗️ Architecture

\`\`\`
┌─────────────────────────────────────────────────────────────────┐
│                        Joueurs                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Infrared Proxy                               │
│              (Scale-to-zero, Wake-on-connect)                   │
│                      Port 25565                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Minecraft Server (Paper)                       │
│               itzg/minecraft-server:java21                       │
│                 ENABLE_AUTOSTOP=true                            │
│                    Aikars Flags                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│   Prometheus     │ │   Restic Backup  │ │    Packwiz       │
│    Exporter      │ │      → S3        │ │   Mod Server     │
│   Port 9225      │ │   Deduplicated   │ │   Port 8080      │
└──────────────────┘ └──────────────────┘ └──────────────────┘
\`\`\`

## 🚀 Démarrage rapide

### 1. Cloner le dépôt

\`\`\`bash
git clone https://github.com/Guilhem-Bonnet/minecraft-server.git
cd minecraft-server
\`\`\`

### 2. Provisionnement de linfrastructure (Terraform)

\`\`\`bash
cd terraform

# Copier et configurer les variables
cp prod.tfvars.example prod.tfvars
# Éditer prod.tfvars avec vos valeurs

# Initialiser et appliquer
terraform init
terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
\`\`\`

### 3. Déploiement du serveur (Ansible)

\`\`\`bash
cd ansible

# Configurer linventaire
# Éditer inventories/prod/hosts.ini et host_vars/

# Déployer
ansible-playbook playbooks/deploy-minecraft.yml -i inventories/prod/hosts.ini
\`\`\`

### 4. Déploiement Docker uniquement

Si vous avez déjà un serveur, vous pouvez utiliser Docker Compose directement :

\`\`\`bash
cd docker

# Copier et configurer lenvironnement
cp .env.example .env
# Éditer .env

# Démarrer les services
docker compose up -d
\`\`\`

## 🔧 Configuration

### Variables principales

| Variable | Description | Défaut |
|----------|-------------|--------|
| \`minecraft_version\` | Version Minecraft | \`1.21.4\` |
| \`minecraft_type\` | Type de serveur | \`PAPER\` |
| \`minecraft_memory\` | Mémoire allouée | \`6G\` |
| \`minecraft_autostop_timeout\` | Timeout avant arrêt (sec) | \`300\` |
| \`minecraft_backup_enabled\` | Activer les backups | \`true\` |
| \`minecraft_prometheus_enabled\` | Activer les métriques | \`true\` |
| \`minecraft_packwiz_enabled\` | Activer la distribution de mods | \`true\` |

## 📦 Gestion des Mods

### Ajouter un mod

\`\`\`bash
./scripts/manage-mods.sh add-modrinth sodium
./scripts/manage-mods.sh add-modrinth lithium
\`\`\`

### Pour les joueurs

1. Télécharger [Prism Launcher](https://prismlauncher.org/)
2. **Ajouter une instance** → **Importer depuis Modrinth**
3. Entrer lURL : \`http://votre-serveur:8080/pack.toml\`
4. Les mods seront automatiquement mis à jour !

## 💾 Backups

\`\`\`bash
# Créer un backup
./scripts/backup.sh backup

# Lister les backups
./scripts/backup.sh list

# Restaurer
./scripts/backup.sh restore latest
\`\`\`

## 📊 Monitoring

Endpoint Prometheus : \`http://serveur:9225/metrics\`

## ⚡ Scale-to-Zero

Le serveur sarrête après 5 minutes sans joueurs. À la connexion, Infrared démarre automatiquement le serveur.

## 📝 License

MIT License
