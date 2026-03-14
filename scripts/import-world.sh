#!/usr/bin/env bash
# =============================================================================
# import-world.sh — Importer la world "Canada's World" dans le PVC Minecraft
# =============================================================================
# Usage :
#   ./scripts/import-world.sh /chemin/vers/wetransfer_canada-s-world_*.zip
#
# Prérequis :
#   - kubectl configuré sur le cluster K3s
#   - Le namespace minecraft et le PVC minecraft-data doivent exister (FluxCD)
#   - Le déploiement minecraft peut être arrêté ou non (le script gère les deux)
#
# Ce que fait ce script :
#   1. Déploie un pod importer temporaire monté sur le PVC minecraft-data
#   2. kubectl cp du zip local → pod
#   3. Extrait le zip et renomme "Canada's World" → "world"
#   4. Vérifie la présence du level.dat
#   5. Supprime le pod importer
#   6. Redémarre le deployment minecraft
# =============================================================================

set -euo pipefail

WORLD_ZIP="${1:-}"
NAMESPACE="minecraft"
PVC_NAME="minecraft-data"
IMPORTER_POD="minecraft-world-importer"
WORLD_DIR_IN_ZIP="Canada's World"
TARGET_WORLD_DIR="world"

# ────────────── Couleurs ──────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ────────────── Validation ────────────────────────────────────────────────────
[[ -z "$WORLD_ZIP" ]] && error "Usage: $0 /path/to/world.zip"
[[ ! -f "$WORLD_ZIP" ]] && error "Fichier introuvable: $WORLD_ZIP"

info "Vérification de la connexion au cluster..."
kubectl get nodes -o name > /dev/null 2>&1 || error "kubectl: impossible de joindre le cluster"

info "Vérification que le namespace '$NAMESPACE' existe..."
kubectl get namespace "$NAMESPACE" > /dev/null 2>&1 || \
  error "Namespace '$NAMESPACE' introuvable. Lance d'abord: flux reconcile kustomization apps --with-source"

info "Vérification que le PVC '$PVC_NAME' existe..."
kubectl get pvc -n "$NAMESPACE" "$PVC_NAME" > /dev/null 2>&1 || \
  error "PVC '$PVC_NAME' introuvable. Attend la création par FluxCD."

# ────────────── Arrêt du serveur ──────────────────────────────────────────────
info "Mise à l'échelle du déploiement minecraft à 0 (évite les écritures concurrentes)..."
kubectl scale deployment minecraft -n "$NAMESPACE" --replicas=0 --timeout=60s || \
  warn "Déploiement introuvable ou déjà à 0 — on continue"

# ────────────── Pod importer ──────────────────────────────────────────────────
info "Suppression d'un éventuel pod importer résiduel..."
kubectl delete pod "$IMPORTER_POD" -n "$NAMESPACE" --ignore-not-found=true --wait=true

info "Démarrage du pod importer (Alpine + unzip sur le PVC)..."
kubectl apply -n "$NAMESPACE" -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${IMPORTER_POD}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: minecraft-importer
spec:
  restartPolicy: Never
  automountServiceAccountToken: false
  securityContext:
    fsGroup: 1000
  containers:
    - name: importer
      image: alpine:3.21
      command: ["sh", "-c", "sleep 3600"]
      securityContext:
        runAsUser: 0  # root pour unzip + chown
        allowPrivilegeEscalation: false
        capabilities:
          drop: ["ALL"]
          add: ["CHOWN", "DAC_OVERRIDE"]
        seccompProfile:
          type: RuntimeDefault
      volumeMounts:
        - name: data
          mountPath: /data
      resources:
        requests: {cpu: "100m", memory: "128Mi"}
        limits:   {cpu: "500m", memory: "512Mi"}
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: ${PVC_NAME}
  nodeSelector:
    kubernetes.io/hostname: predator-k3s
EOF

info "Attente du pod importer (Running)..."
kubectl wait pod "$IMPORTER_POD" -n "$NAMESPACE" --for=condition=Ready --timeout=120s

# ────────────── Installation de unzip dans le pod ────────────────────────────
info "Installation de unzip dans le pod..."
kubectl exec -n "$NAMESPACE" "$IMPORTER_POD" -- apk add --no-cache unzip > /dev/null

# ────────────── Vérification world existante ─────────────────────────────────
EXISTING_WORLD=$(kubectl exec -n "$NAMESPACE" "$IMPORTER_POD" -- \
  sh -c "[ -f /data/${TARGET_WORLD_DIR}/level.dat ] && echo 'yes' || echo 'no'")

if [[ "$EXISTING_WORLD" == "yes" ]]; then
  warn "Une world '${TARGET_WORLD_DIR}' existe déjà dans le PVC."
  read -rp "Écraser ? [y/N] " confirm
  [[ "$confirm" != "y" && "$confirm" != "Y" ]] && \
    { info "Annulé. Pod nettoyé."; kubectl delete pod "$IMPORTER_POD" -n "$NAMESPACE" --ignore-not-found=true; exit 0; }
  info "Sauvegarde de l'ancienne world → ${TARGET_WORLD_DIR}.bak..."
  kubectl exec -n "$NAMESPACE" "$IMPORTER_POD" -- \
    sh -c "rm -rf /data/${TARGET_WORLD_DIR}.bak && mv /data/${TARGET_WORLD_DIR} /data/${TARGET_WORLD_DIR}.bak"
fi

# ────────────── Copie du zip ──────────────────────────────────────────────────
ZIP_FILENAME=$(basename "$WORLD_ZIP")
info "Copie du zip vers le pod (peut prendre quelques minutes pour 2.6GB)..."
kubectl cp "$WORLD_ZIP" "${NAMESPACE}/${IMPORTER_POD}:/tmp/${ZIP_FILENAME}"

# ────────────── Extraction ───────────────────────────────────────────────────
info "Extraction du zip dans /data/..."
kubectl exec -n "$NAMESPACE" "$IMPORTER_POD" -- \
  sh -c "cd /data && unzip -q /tmp/${ZIP_FILENAME}"

# ────────────── Renommage ─────────────────────────────────────────────────────
info "Renommage '${WORLD_DIR_IN_ZIP}' → '${TARGET_WORLD_DIR}'..."
kubectl exec -n "$NAMESPACE" "$IMPORTER_POD" -- \
  sh -c "mv /data/'${WORLD_DIR_IN_ZIP}' /data/${TARGET_WORLD_DIR}"

# ────────────── Permissions ───────────────────────────────────────────────────
info "Application des permissions uid 1000 sur /data/${TARGET_WORLD_DIR}..."
kubectl exec -n "$NAMESPACE" "$IMPORTER_POD" -- \
  chown -R 1000:1000 "/data/${TARGET_WORLD_DIR}"

# ────────────── Nettoyage ─────────────────────────────────────────────────────
info "Suppression du zip temporaire..."
kubectl exec -n "$NAMESPACE" "$IMPORTER_POD" -- rm -f "/tmp/${ZIP_FILENAME}"

# ────────────── Vérification ─────────────────────────────────────────────────
info "Vérification du level.dat..."
kubectl exec -n "$NAMESPACE" "$IMPORTER_POD" -- \
  sh -c "ls -lh /data/${TARGET_WORLD_DIR}/level.dat" || \
  error "level.dat introuvable après extraction !"

WORLD_SIZE=$(kubectl exec -n "$NAMESPACE" "$IMPORTER_POD" -- \
  sh -c "du -sh /data/${TARGET_WORLD_DIR} | cut -f1")
info "World importée avec succès ! Taille : ${WORLD_SIZE}"

# ────────────── Nettoyage pod importer ───────────────────────────────────────
info "Suppression du pod importer..."
kubectl delete pod "$IMPORTER_POD" -n "$NAMESPACE" --ignore-not-found=true

# ────────────── Redémarrage du serveur ───────────────────────────────────────
info "Redémarrage du déploiement minecraft (replicas=1)..."
kubectl scale deployment minecraft -n "$NAMESPACE" --replicas=1

info "Suivi du démarrage (Ctrl+C pour quitter le suivi, le serveur continue)..."
kubectl rollout status deployment/minecraft -n "$NAMESPACE" --timeout=360s

info ""
info "✅ Import terminé ! Serveur minecraft démarré avec la world 'Canada's World'"
info "   IP joueurs : 192.168.2.83:25565"
info "   Logs       : kubectl logs -n minecraft deploy/minecraft -f"
info "   Console    : kubectl exec -n minecraft deploy/minecraft -- mc-monitor tee --fifo"
