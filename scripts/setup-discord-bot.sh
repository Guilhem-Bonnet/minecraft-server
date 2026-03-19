#!/usr/bin/env bash
# =============================================================================
# setup-discord-bot.sh — Créer le secret K8s pour le bot Discord Minecraft
# =============================================================================
# Ce script :
#   1. Déchiffre le discord_bot_token depuis gaming-secrets.sops.yml (Ansible)
#   2. Demande l'ID du channel Discord (ou le lit depuis l'env)
#   3. Crée le secret K8s `minecraft-discord-bot` dans le namespace minecraft
#
# Usage :
#   cd infra-prod-home-
#   bash ../minecraft-server/scripts/setup-discord-bot.sh
#
#   Ou avec le channel_id en variable :
#   DISCORD_CHANNEL_ID=123456789 bash ../minecraft-server/scripts/setup-discord-bot.sh
# =============================================================================
set -euo pipefail

NAMESPACE="minecraft"
SECRET_NAME="minecraft-discord-bot"
GAMING_SECRETS="ansible/inventories/prod/group_vars/all/gaming-secrets.sops.yml"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Vérifications prérequis ────────────────────────────────────────────────
command -v sops   &>/dev/null || error "sops non trouvé — requis pour déchiffrer gaming-secrets.sops.yml"
command -v python3 &>/dev/null || error "python3 non trouvé"
command -v kubectl &>/dev/null || error "kubectl non trouvé"

[[ -f "$GAMING_SECRETS" ]] || error "Fichier introuvable : $GAMING_SECRETS (lancer depuis infra-prod-home-/)"

# ── Vérifier que le namespace existe ──────────────────────────────────────
kubectl get namespace "$NAMESPACE" &>/dev/null || error "Namespace $NAMESPACE introuvable — déployer le serveur Minecraft d'abord."

# ── Déchiffrer le bot token ───────────────────────────────────────────────
info "Déchiffrement de $GAMING_SECRETS..."
BOT_TOKEN=$(sops -d "$GAMING_SECRETS" | python3 -c "
import sys, yaml
data = yaml.safe_load(sys.stdin)
token = data.get('discord_bot_token', '')
if not token:
    exit(1)
print(token)
" 2>/dev/null) || error "Impossible de lire discord_bot_token depuis $GAMING_SECRETS"

[[ -n "$BOT_TOKEN" ]] || error "discord_bot_token vide dans $GAMING_SECRETS"
info "Bot token récupéré ✅"

# ── Channel Discord ────────────────────────────────────────────────────────
if [[ -z "${DISCORD_CHANNEL_ID:-}" ]]; then
    echo ""
    warn "DISCORD_CHANNEL_ID non défini."
    echo "Pour trouver l'ID : Discord → activer Mode Développeur → clic droit sur le channel #minecraft → Copier l'identifiant"
    echo ""
    read -rp "ID du channel #minecraft (Entrée = 0 = pas de restriction) : " DISCORD_CHANNEL_ID
    DISCORD_CHANNEL_ID="${DISCORD_CHANNEL_ID:-0}"
fi

info "Channel ID : $DISCORD_CHANNEL_ID"

# ── Suppression du secret existant si présent ────────────────────────────
if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null; then
    warn "Secret $SECRET_NAME déjà présent — suppression et recréation..."
    kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE"
fi

# ── Création du secret ────────────────────────────────────────────────────
info "Création du secret $SECRET_NAME dans le namespace $NAMESPACE..."
kubectl create secret generic "$SECRET_NAME" \
    -n "$NAMESPACE" \
    --from-literal="DISCORD_BOT_TOKEN=${BOT_TOKEN}" \
    --from-literal="DISCORD_CHANNEL_ID=${DISCORD_CHANNEL_ID}"

info "Secret créé ✅"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Prochaine étape : déployer le bot"
echo "   kubectl apply -f k8s/apps/minecraft/discord-bot-code-configmap.yaml"
echo "   kubectl apply -f k8s/apps/minecraft/discord-bot.yaml"
echo ""
echo " Vérifier les logs :"
echo "   kubectl logs -n minecraft -l app.kubernetes.io/name=minecraft-discord-bot -f"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
