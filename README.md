# Minecraft Server — Canada's World

Serveur Minecraft Java Edition déployé sur K3s via FluxCD GitOps.

## Infos

| Propriété | Valeur |
|---|---|
| Adresse joueurs | `192.168.2.83:25565` |
| Version MC | 1.21.11 (Java Edition) |
| Type | Paper (performance optimale) |
| World | Canada's World |
| Node K3s | predator-k3s |
| PVC Longhorn | 30Gi (`minecraft-data`) |

## Structure

```
minecraft-server/
├── scripts/
│   └── import-world.sh   # Import initial de la world depuis un zip local
└── README.md
```

Les manifests K8s sont dans `infra-prod-home-/k8s/apps/minecraft/`.

## Déploiement initial

### 1. Pousser les manifests

```bash
cd infra-prod-home-
git add k8s/apps/minecraft/
git commit -m "feat(minecraft): déploiement Canada's World 1.21.11"
git push
# FluxCD reconcile en ~2min
flux reconcile kustomization apps --with-source
```

### 2. Attendre la création du PVC et du namespace

```bash
kubectl get all -n minecraft
kubectl get pvc -n minecraft
# Attendre que PVC minecraft-data soit Bound
```

### 3. Importer la world

```bash
cd minecraft-server
bash scripts/import-world.sh ~/Téléchargements/wetransfer_canada-s-world_2026-03-13_1751.zip
```

Le script :
- Arrête proprement le serveur (replicas=0)
- Déploie un pod Alpine temporaire sur le même PVC
- Copie + extrait le zip (~2.6GB)
- Renomme "Canada's World" → "world"
- Redémarre le serveur (replicas=1)

### 4. Vérifier le démarrage

```bash
# Logs en direct
kubectl logs -n minecraft deploy/minecraft -f

# Statut
kubectl get pods -n minecraft -w

# Console interactive (une fois le serveur prêt)
kubectl exec -n minecraft deploy/minecraft -- mc-monitor tee --fifo
```

## Opérations courantes

### Envoyer une commande serveur

```bash
kubectl exec -n minecraft deploy/minecraft -- mc-monitor tee --fifo
# puis taper : /op <username>
```

### Redémarrer le serveur

```bash
kubectl rollout restart deployment/minecraft -n minecraft
```

### Mise à jour de la version Minecraft

1. Modifier `VERSION` dans `k8s/apps/minecraft/deployment.yaml`
2. Commiter + pousser → FluxCD reconstruit avec la nouvelle version

### Sauvegarde manuelle immédiate

```bash
velero backup create minecraft-manual \
  --include-namespaces=minecraft \
  --default-volumes-to-fs-backup \
  -n velero
```

### Accès RCON (commandes admin)

```bash
# Récupérer le mot de passe RCON
RCON_PASS=$(kubectl get secret minecraft-secret -n minecraft \
  -o jsonpath='{.data.RCON_PASSWORD}' | base64 -d)

# Via rcon-cli depuis un pod debug
kubectl run rcon-cli -n minecraft --rm -it --image=itzg/rcon-cli --restart=Never \
  -- --host minecraft-rcon --port 25575 --password "$RCON_PASS"
```

## Backups automatiques

- **Daily** (02:00 UTC) : Velero backup du namespace `minecraft` + PVC (kopia/fs-backup), rétention 30j
- **Weekly** (dimanche 03:00 UTC) : Backup complet cluster, rétention 90j

## Monitoring

Les logs sont collectés par Grafana Alloy (DaemonSet). Visible dans Grafana → Explore → Logs → `namespace=minecraft`.
