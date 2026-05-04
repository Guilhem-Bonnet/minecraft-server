# Backend S3 — minecraft-server gaming-server
# Préfixe `minecraft/` du bucket prod homelab (cohérent avec la convention
# documentée dans infra-prod-home-/docs/architecture/STATE_LAYOUT.md).

terraform {
  backend "s3" {
    bucket         = "homelab-backups-guilhem-2025"
    key            = "terraform/state/minecraft/gaming-server/terraform.tfstate"
    region         = "ca-central-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locks"
  }
}
