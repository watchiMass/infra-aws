# RUNBOOK — Application de la plateforme GitOps (dev)

> Séquence complète pour appliquer l'infrastructure codée dans ce dépôt et
> dans `gitops-platform` / `gitops-apps`. Durée totale : ~45 min d'actions
> manuelles + 15-30 min de réconciliation Flux (HelmReleases lourdes,
> montée en charge des nœuds par le cluster-autoscaler).

---

## 0. Vue d'ensemble

```
Prérequis machine ──► Apply Terraform ──► Push du contenu Git
      (~10 min)        (~15-20 min)       (~5 min)
        │
        ▼
Tâches post-apply ──► Validation ──► Exploitation
    (~15 min)         (~15 min)
```

L'apply Terraform crée : VPC, cluster EKS `dev-eks` (1.36), rôles IRSA,
zone DNS `dev.jerielmass.com`, dépôts GitHub privés, registre ECR, buckets
d'observabilité — puis **bootstrap Flux** automatiquement (fin de l'apply).

---

## 1. Prérequis machine

### 1.1 Authentification AWS (SSO standard — une fois par session, ~8 h)

```bash
aws sso login --profile devops-admin
```

Puis travailler avec `AWS_PROFILE=devops-admin` (ou l'exporter une fois
dans le shell) :

```bash
export AWS_PROFILE=devops-admin
aws sts get-caller-identity
```

> ✅ Méthode stable validée : Terraform résout le profil SSO **nativement**
> et rafraîchit automatiquement les credentials de rôle tant que le token
> SSO est valide (~8 h). Aucun `eval`/pont manuel.
>
> ⚠️ Ne pas utiliser `aws login` + `aws configure export-credentials` : ce
> mécanisme Omarchy est propriétaire, Terraform ne le comprend pas, et il
> produit des erreurs transitoires « refreshed credentials still expired ».
>
> 🔧 Pour allonger la session : console AWS → IAM Identity Center →
> Permission sets → AdministratorAccess → Session duration → 8 hours.

### 1.2 CLI Flux (requis par le bootstrap intégré à l'apply)

```bash
sudo pacman -S --needed --noconfirm fluxcd
flux --version
```

### 1.3 PAT GitHub

- Créer un token **classic** (https://github.com/settings/tokens), scope `repo` ;
- Un fine-grained ne convient pas : il ne peut pas être scopé sur des dépôts
  qui n'existent pas encore (créés pendant l'apply) ;
- Le token sert au provider GitHub Terraform **et** au bootstrap Flux ;
- Ne jamais le committer : uniquement en variable d'environnement.

### 1.4 `gh` (pour créer le dépôt `infra-aws` au §3)

```bash
gh auth login
```

---

## 2. Apply Terraform

```bash
cd infra-aws/terraform/environments/dev

# 2.1 Profil SSO + token (même shell)
export AWS_PROFILE=devops-admin
export TF_VAR_github_token=<TON-PAT>

# 2.2 Init (backend S3 gitops01-state — bucket déjà créé)
terraform init

# 2.3 Plan frais (l'ancien /tmp/tfplan-dev est périmé) — revue rapide
terraform plan

# 2.4 Apply (~15-20 min)
terraform apply
```

À la fin de l'apply :
- `update_kubeconfig` a écrit `~/.kube/config` (contexte `dev-eks`) ;
- `flux bootstrap` a installé Flux et poussé `clusters/dev/flux-system/`
  dans le dépôt GitHub `gitops-platform` ;
- Le dépôt `gitops-platform` contient aussi `clusters/dev/metadata.yaml`
  (ConfigMap `cluster-metadata`, écrite par Terraform).

Vérification immédiate :

```bash
terraform output
kubectl get nodes            # 2 nœuds Ready (autoscaler en ajoutera d'autres)
```

---

## 3. Push du contenu local des dépôts

> ⚠️ **Jamais de force-push** : les dépôts `gitops-platform` et
> `gitops-apps` ont déjà des commits créés par l'apply (auto_init README,
> metadata.yaml, flux-system). Stratégie : `fetch` + `rebase`.

### 3.1 `infra-aws` (dépôt GitHub inexistant → création via gh)

```bash
cd infra-aws
gh repo create watchiMass/infra-aws --private --source . --push
```

### 3.2 `gitops-platform`

```bash
cd gitops-platform
git remote add origin git@github.com:watchiMass/gitops-platform.git
git fetch origin
git rebase origin/main
# Conflit attendu sur README.md : garder NOTRE version (plus riche)
git checkout --ours README.md && git add README.md
git rebase --continue
git push -u origin main
```

### 3.3 `gitops-apps`

```bash
cd gitops-apps
git remote add origin git@github.com:watchiMass/gitops-apps.git
git fetch origin
git rebase origin/main
git checkout --ours README.md && git add README.md   # idem
git rebase --continue
git push -u origin main
```

---

## 4. Tâches post-apply (DANS CET ORDRE)

### 4.1 Vérifier le cluster

```bash
kubectl get nodes          # Ready
kubectl get pods -A        # pods système Running
```

### 4.2 Secret de déchiffrement SOPS

```bash
cd gitops-platform
kubectl create secret generic sops-age -n flux-system --from-file=age.agekey
```

### 4.3 Activer SOPS sur le kustomize-controller

```bash
kubectl patch deployment kustomize-controller -n flux-system --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/1/args/-","value":"--decryption-provider=sops"},
  {"op":"add","path":"/spec/template/spec/containers/1/args/-","value":"--sops-age-key-file=/sops/age.agekey"},
  {"op":"add","path":"/spec/template/spec/containers/1/volumeMounts/-","value":{"name":"sops-age","mountPath":"/sops"}},
  {"op":"add","path":"/spec/template/spec/volumes/-","value":{"name":"sops-age","secret":{"secretName":"sops-age"}}}]'
```

### 4.4 Éditer la Kustomization racine générée par bootstrap

Fichier `gitops-platform/clusters/dev/flux-system/kustomization.yaml`
(récupérer l'ARN : `terraform output image_reflector_role_arn`) :

```yaml
spec:
  # ajouter après les champs existants :
  decryption:
    provider: sops
    secretRef:
      name: sops-age
  patches:
    - patch: |
        apiVersion: v1
        kind: ServiceAccount
        metadata:
          name: image-reflector-controller
          namespace: flux-system
          annotations:
            eks.amazonaws.com/role-arn: <IMAGE_REFLECTOR_ROLE_ARN>
```

Puis committer + pousser. Flux se réconcilie tout seul :

```bash
git add clusters/dev/flux-system/kustomization.yaml
git commit -m "feat(flux): décryption SOPS + IRSA image-reflector sur la racine"
git push
flux reconcile kustomization flux-system -n flux-system   # pour accélérer
```

### 4.5 Délégation DNS `dev.jerielmass.com`

```bash
terraform output zone_name_servers
```

Créer ces 4 enregistrements **NS** pour le sous-domaine `dev` dans la zone
parente `jerielmass.com` (interface OVH : Zone DNS → ajouter une entrée NS
« dev » → coller les 4 name servers Route 53). Le site web existant sur
`jerielmass.com` n'est pas affecté. Sans cette délégation : pas de
résolution publique → les certificats Let's Encrypt (HTTP-01) échoueront
et réessaieront automatiquement jusqu'à ce que ce soit fait.

### 4.6 Attendre la réconciliation Flux

```bash
flux get kustomizations
# Attendu : sources, flux-config, infrastructure, observability, apps — Ready
flux get helmreleases -A
flux events            # en cas de doute
```

> La première réconciliation installe 13 HelmReleases et peut déclencher
> une montée en charge des nœuds : compter 15-30 min.

---

## 5. Validation

```bash
# Kustomizations et HelmReleases
flux get kustomizations           # toutes Ready=True
flux get helmreleases -A          # toutes Released

# Secrets SOPS déchiffrés dans le cluster
kubectl -n observability get secret grafana-admin   # EXISTE

# Alertes
kubectl -n observability get prometheusrule          # slo-alerts
kubectl -n observability port-forward svc/kube-prometheus-stack-alertmanager 9093:9093
# → http://localhost:9093 : TestAlert visible (firing)

# Grafana
kubectl -n observability port-forward svc/kube-prometheus-stack-grafana 3000:80
# → http://localhost:3000 — login admin / mot de passe :
sops -d clusters/dev/secrets/grafana-admin.yaml | grep admin-password
# → vérifier 3 datasources : Prometheus, Loki, Tempo (+ corrélation trace→logs)

# Portfolio (après ton premier push CI semver — voir §6)
curl -s https://portfolio.dev.jerielmass.com | head
```

---

## 6. Dépannage

| Symptôme | Diagnostic |
|---|---|
| `Kustomization` en erreur | `flux get kustomization <nom>` → `flux events` → `flux reconcile kustomization <nom>` |
| `HelmRelease` bloquée | `helm list -n <ns>` · `kubectl describe helmrelease -n <ns> <nom>` |
| **Portfolio en `ImagePullBackOff`** | **Attendu** : l'image `0.1.0` n'existe pas encore. Ton premier push CI avec un tag semver ≥1.0.0 déclenche l'automation (§5.7) |
| Certificat TLS non émis | Délégation DNS §4.5 faite ? `kubectl -n cert-manager get certificate,order` |
| Alertes absentes de Grafana | `kubectl get servicemonitors -A` · cibles Prometheus (`/targets`) |
| Pods en attente (ressources) | `kubectl top nodes` — l'autoscaler ajoute des nœuds (max 6) |
| `flux get sources` : gitops-apps pas Ready | PAT valide ? secret `flux-system` correct ? dépôt privé accessible ? |

---

## 7. Checklist finale

- [ ] `terraform apply` OK, `kubectl get nodes` Ready
- [ ] Dépôts GitHub : infra-aws, gitops-platform, gitops-apps contiennent tout le code
- [ ] `flux get kustomizations` : sources, flux-config, infrastructure, observability, apps — Ready
- [ ] 13 HelmReleases Released (dont ingress-nginx en NLB, cert-manager, Loki, Tempo)
- [ ] Grafana accessible en HTTPS (https://grafana.dev.jerielmass.com), 3 datasources
- [ ] TestAlert visible dans Alertmanager
- [ ] Délégation DNS dev.jerielmass.com effectuée
- [ ] Certificats Let's Encrypt émis (grafana, portfolio)
- [ ] Premier push CI dev-portfolio → image ECR → automation Flux → déploiement
- [ ] `curl https://portfolio.dev.jerielmass.com` répond
- [ ] HPA et ScaledObject actifs (`kubectl get hpa -n apps-dev-portfolio`,
      `kubectl get scaledobject -n ingress-nginx`)
