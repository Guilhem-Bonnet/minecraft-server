#!/bin/bash
#
# Minecraft Backup Script - Intelligent backup vers S3
#
# Features:
# - Pause les saves MC pendant le backup (cohérence)
# - Déduplication avec restic
# - Rotation automatique (hourly, daily, weekly, monthly)
# - Support des tags pour backups événementiels
# - Notifications optionnelles
#
# Usage:
#   ./backup.sh                    # Backup standard
#   ./backup.sh --tag pre-update   # Backup avec tag
#   ./backup.sh --init             # Initialiser le repo
#   ./backup.sh --list             # Lister les backups
#   ./backup.sh --restore latest   # Restaurer le dernier
#   ./backup.sh --restore 2025-12-01  # Restaurer une date

set -euo pipefail

# === Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../docker/.env" 2>/dev/null || true

# Paths
MINECRAFT_DATA="${DATA_PATH:-/opt/minecraft/data}"
BACKUP_LOG="/var/log/minecraft-backup.log"

# S3 Configuration
export RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-s3:${S3_ENDPOINT}/${S3_BUCKET}}"
export RESTIC_PASSWORD="${RESTIC_PASSWORD}"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"

# RCON Configuration
RCON_HOST="${RCON_HOST:-localhost}"
RCON_PORT="${RCON_PORT:-25575}"
RCON_PASSWORD="${RCON_PASSWORD}"

# Retention Policy
KEEP_HOURLY=${KEEP_HOURLY:-6}
KEEP_DAILY=${KEEP_DAILY:-7}
KEEP_WEEKLY=${KEEP_WEEKLY:-4}
KEEP_MONTHLY=${KEEP_MONTHLY:-6}

# === Couleurs ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# === Fonctions utilitaires ===
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${BACKUP_LOG}"
}

info() { log "INFO" "${GREEN}$*${NC}"; }
warn() { log "WARN" "${YELLOW}$*${NC}"; }
error() { log "ERROR" "${RED}$*${NC}"; }

# Vérifier si le serveur MC est en cours d'exécution
mc_is_running() {
    docker ps --filter "name=minecraft" --filter "status=running" -q | grep -q .
}

# Exécuter une commande RCON
rcon_cmd() {
    local cmd="$1"
    if mc_is_running; then
        docker exec minecraft rcon-cli "$cmd" 2>/dev/null || true
    fi
}

# Désactiver les sauvegardes auto MC (cohérence)
mc_save_off() {
    if mc_is_running; then
        info "🔒 Désactivation des sauvegardes MC..."
        rcon_cmd "save-off"
        rcon_cmd "save-all"
        sleep 5  # Attendre que le flush soit complet
    fi
}

# Réactiver les sauvegardes auto MC
mc_save_on() {
    if mc_is_running; then
        info "🔓 Réactivation des sauvegardes MC..."
        rcon_cmd "save-on"
    fi
}

# Notifier les joueurs
mc_notify() {
    local message="$1"
    if mc_is_running; then
        rcon_cmd "say §6[Backup] §f${message}"
    fi
}

# === Commandes principales ===

cmd_init() {
    info "🔧 Initialisation du repository restic..."
    
    if restic snapshots &>/dev/null; then
        warn "Le repository existe déjà"
        return 0
    fi
    
    restic init
    info "✅ Repository initialisé avec succès"
}

cmd_backup() {
    local tag="${1:-}"
    local backup_tags="--tag minecraft"
    
    if [[ -n "$tag" ]]; then
        backup_tags="$backup_tags --tag $tag"
        info "📦 Backup avec tag: $tag"
    fi
    
    # Vérifications
    if [[ ! -d "$MINECRAFT_DATA" ]]; then
        error "Dossier de données non trouvé: $MINECRAFT_DATA"
        exit 1
    fi
    
    # Notifier les joueurs
    mc_notify "Backup en cours... Possible micro-lag."
    
    # Désactiver les saves pour cohérence
    mc_save_off
    
    # Trap pour réactiver les saves même en cas d'erreur
    trap mc_save_on EXIT
    
    info "📤 Démarrage du backup..."
    local start_time=$(date +%s)
    
    # Backup avec restic
    restic backup \
        $backup_tags \
        --exclude "*.log" \
        --exclude "*.log.*" \
        --exclude "cache/*" \
        --exclude "logs/*" \
        --exclude ".git/*" \
        --exclude "crash-reports/*" \
        --one-file-system \
        "$MINECRAFT_DATA"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Réactiver les saves
    mc_save_on
    trap - EXIT
    
    # Stats
    info "✅ Backup terminé en ${duration}s"
    mc_notify "Backup terminé!"
    
    # Cleanup automatique
    cmd_prune
}

cmd_prune() {
    info "🧹 Nettoyage des anciens backups..."
    
    restic forget \
        --keep-hourly $KEEP_HOURLY \
        --keep-daily $KEEP_DAILY \
        --keep-weekly $KEEP_WEEKLY \
        --keep-monthly $KEEP_MONTHLY \
        --prune
    
    info "✅ Nettoyage terminé"
}

cmd_list() {
    info "📋 Liste des backups disponibles:"
    restic snapshots --tag minecraft
}

cmd_restore() {
    local target="${1:-latest}"
    local restore_path="${2:-/tmp/minecraft-restore}"
    
    warn "⚠️  ATTENTION: Cette opération va restaurer les données!"
    warn "   Les données seront restaurées dans: $restore_path"
    read -p "Continuer? [y/N] " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Restauration annulée"
        return 0
    fi
    
    # Arrêter le serveur si en cours
    if mc_is_running; then
        warn "⚠️  Arrêt du serveur Minecraft..."
        docker stop minecraft
    fi
    
    info "📥 Restauration du backup: $target"
    mkdir -p "$restore_path"
    
    if [[ "$target" == "latest" ]]; then
        restic restore latest --target "$restore_path" --tag minecraft
    else
        # Chercher par date ou ID
        local snapshot_id=$(restic snapshots --tag minecraft --json | \
            jq -r ".[] | select(.time | startswith(\"$target\")) | .id" | head -1)
        
        if [[ -z "$snapshot_id" ]]; then
            snapshot_id="$target"  # Peut-être un ID direct
        fi
        
        restic restore "$snapshot_id" --target "$restore_path"
    fi
    
    info "✅ Restauration terminée dans: $restore_path"
    info "   Pour appliquer: cp -r $restore_path/* $MINECRAFT_DATA/"
}

cmd_check() {
    info "🔍 Vérification de l'intégrité du repository..."
    restic check
    info "✅ Repository OK"
}

cmd_stats() {
    info "📊 Statistiques du repository:"
    restic stats --mode raw-data
}

cmd_diff() {
    local snap1="${1:-}"
    local snap2="${2:-latest}"
    
    if [[ -z "$snap1" ]]; then
        # Comparer les deux derniers
        local snaps=$(restic snapshots --tag minecraft --json | jq -r '.[].id' | tail -2)
        snap1=$(echo "$snaps" | head -1)
        snap2=$(echo "$snaps" | tail -1)
    fi
    
    info "📊 Différences entre $snap1 et $snap2:"
    restic diff "$snap1" "$snap2"
}

# === Main ===
main() {
    local cmd="${1:-backup}"
    shift || true
    
    case "$cmd" in
        --init|init)
            cmd_init
            ;;
        --backup|backup)
            cmd_backup "$@"
            ;;
        --tag)
            cmd_backup "$1"
            ;;
        --prune|prune)
            cmd_prune
            ;;
        --list|list|ls)
            cmd_list
            ;;
        --restore|restore)
            cmd_restore "$@"
            ;;
        --check|check)
            cmd_check
            ;;
        --stats|stats)
            cmd_stats
            ;;
        --diff|diff)
            cmd_diff "$@"
            ;;
        --help|help|-h)
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  init              Initialiser le repository S3"
            echo "  backup            Effectuer un backup (défaut)"
            echo "  --tag NAME        Backup avec un tag spécifique"
            echo "  prune             Nettoyer les anciens backups"
            echo "  list              Lister les backups disponibles"
            echo "  restore [TARGET]  Restaurer (latest ou date/ID)"
            echo "  check             Vérifier l'intégrité"
            echo "  stats             Statistiques d'utilisation"
            echo "  diff [S1] [S2]    Comparer deux snapshots"
            ;;
        *)
            error "Commande inconnue: $cmd"
            exit 1
            ;;
    esac
}

main "$@"
