#!/bin/bash
#
# Script de gestion des mods pour le serveur Minecraft
# Utilise packwiz pour gérer les mods côté serveur ET client
#
# Prérequis: packwiz installé (go install github.com/packwiz/packwiz@latest)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODPACK_DIR="${SCRIPT_DIR}/../modpack"
MODS_DIR="${SCRIPT_DIR}/../docker/mods"

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

# Vérifier que packwiz est installé
check_packwiz() {
    if ! command -v packwiz &> /dev/null; then
        warn "packwiz n'est pas installé!"
        echo "Installation: go install github.com/packwiz/packwiz@latest"
        echo "Ou télécharger depuis: https://github.com/packwiz/packwiz/releases"
        exit 1
    fi
}

# Ajouter un mod depuis Modrinth
add_modrinth() {
    local mod_slug="$1"
    info "Ajout du mod Modrinth: $mod_slug"
    cd "$MODPACK_DIR"
    packwiz modrinth add "$mod_slug"
}

# Ajouter un mod depuis CurseForge
add_curseforge() {
    local mod_slug="$1"
    info "Ajout du mod CurseForge: $mod_slug"
    cd "$MODPACK_DIR"
    packwiz curseforge add "$mod_slug"
}

# Ajouter un mod depuis URL directe
add_url() {
    local url="$1"
    local name="$2"
    info "Ajout du mod depuis URL: $name"
    cd "$MODPACK_DIR"
    packwiz url add "$url" --name "$name"
}

# Mettre à jour tous les mods
update_all() {
    info "Mise à jour de tous les mods..."
    cd "$MODPACK_DIR"
    packwiz update --all
}

# Rafraîchir l'index
refresh() {
    info "Rafraîchissement de l'index packwiz..."
    cd "$MODPACK_DIR"
    packwiz refresh
}

# Exporter vers format Modrinth (.mrpack)
export_modrinth() {
    local output="${1:-modpack.mrpack}"
    info "Export vers format Modrinth: $output"
    cd "$MODPACK_DIR"
    packwiz modrinth export -o "$output"
    info "✅ Pack exporté: $output"
    info "   Les joueurs peuvent importer ce fichier dans Prism Launcher / Modrinth App"
}

# Exporter vers format CurseForge
export_curseforge() {
    local output="${1:-modpack.zip}"
    info "Export vers format CurseForge: $output"
    cd "$MODPACK_DIR"
    packwiz curseforge export -o "$output"
}

# Synchroniser les mods serveur avec le pack
sync_server() {
    info "Synchronisation des mods serveur..."
    mkdir -p "$MODS_DIR"
    
    # Télécharger les mods côté serveur
    cd "$MODPACK_DIR"
    
    # Packwiz peut installer les mods directement
    # Pour le serveur, on copie uniquement les mods server-side
    packwiz serve &
    local pid=$!
    sleep 2
    
    # Télécharger via l'API packwiz
    curl -s "http://localhost:8080/mods" | while read -r mod_url; do
        wget -q -P "$MODS_DIR" "$mod_url" || true
    done
    
    kill $pid 2>/dev/null || true
    
    info "✅ Mods serveur synchronisés dans: $MODS_DIR"
}

# Lister les mods installés
list_mods() {
    info "Mods installés:"
    cd "$MODPACK_DIR"
    packwiz list
}

# Supprimer un mod
remove_mod() {
    local mod_name="$1"
    info "Suppression du mod: $mod_name"
    cd "$MODPACK_DIR"
    packwiz remove "$mod_name"
}

# Servir le pack pour les clients
serve() {
    local port="${1:-8081}"
    info "Démarrage du serveur packwiz sur le port $port..."
    info "URL pour les joueurs: http://$(hostname -I | awk '{print $1}'):$port/pack.toml"
    cd "$MODPACK_DIR"
    packwiz serve --port "$port"
}

# === Mods recommandés ===
install_recommended() {
    info "Installation des mods recommandés..."
    
    # Performance
    add_modrinth "lithium"           # Optimisations serveur
    add_modrinth "ferritecore"       # Réduction mémoire
    
    # Fabric API (requis)
    add_modrinth "fabric-api"
    
    # Utilitaires admin
    add_modrinth "spark"             # Profiling
    
    refresh
    info "✅ Mods recommandés installés"
}

# === Main ===
main() {
    check_packwiz
    
    local cmd="${1:-help}"
    shift || true
    
    case "$cmd" in
        add-modrinth|mr)
            add_modrinth "$@"
            ;;
        add-curseforge|cf)
            add_curseforge "$@"
            ;;
        add-url)
            add_url "$@"
            ;;
        update)
            update_all
            ;;
        refresh)
            refresh
            ;;
        export-mr|export-modrinth)
            export_modrinth "$@"
            ;;
        export-cf|export-curseforge)
            export_curseforge "$@"
            ;;
        sync-server)
            sync_server
            ;;
        list|ls)
            list_mods
            ;;
        remove|rm)
            remove_mod "$@"
            ;;
        serve)
            serve "$@"
            ;;
        recommended)
            install_recommended
            ;;
        help|--help|-h)
            echo "Gestion des mods Minecraft avec packwiz"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  add-modrinth <slug>   Ajouter un mod depuis Modrinth"
            echo "  add-curseforge <slug> Ajouter un mod depuis CurseForge"  
            echo "  add-url <url> <name>  Ajouter un mod depuis URL"
            echo "  update                Mettre à jour tous les mods"
            echo "  refresh               Rafraîchir l'index"
            echo "  export-modrinth       Exporter en .mrpack (Prism Launcher)"
            echo "  export-curseforge     Exporter en .zip (CurseForge)"
            echo "  sync-server           Synchroniser les mods serveur"
            echo "  list                  Lister les mods installés"
            echo "  remove <name>         Supprimer un mod"
            echo "  serve [port]          Servir le pack pour les clients"
            echo "  recommended           Installer les mods recommandés"
            echo ""
            echo "Workflow joueur:"
            echo "  1. Admin: $0 export-modrinth"
            echo "  2. Joueur: Importer modpack.mrpack dans Prism Launcher"
            echo "  3. Joueur: Lancer et jouer!"
            ;;
        *)
            echo "Commande inconnue: $cmd"
            echo "Utiliser: $0 help"
            exit 1
            ;;
    esac
}

main "$@"
