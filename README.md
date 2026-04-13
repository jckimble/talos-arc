# talos-arc

GitOps-first Talos Kubernetes bootstrap repository.

This repo follows a strict handoff model:

1. Talos creates the Kubernetes control plane.
2. Talos installs a minimal bootstrap seed (Flux namespace + SOPS age secret + Flux Operator install + initial FluxInstance reference).
3. Flux Operator then manages Flux lifecycle, and Flux reconciles everything else from Git.

## Repository layout

- `bootstrap/talos/`: talhelper config, environment values, and generated Talos machine config.
- `clusters/prod/`: cluster-layered Flux entrypoint (`platform` -> `infra` -> `workloads`).
- `infrastructure/`: shared controllers/operators/charts managed by Flux.
- `secrets/prod/`: encrypted SOPS secrets.

## Prerequisites

- `talhelper`
- `talosctl`
- `kubectl`
- `sops` and `age`

This repository includes a dev container with these tools preinstalled.

## Quick start

1. Update bootstrap values in `bootstrap/talos/talenv.yaml`.
2. Ensure `NODE_ADDRESS` resolves and is reachable from where you run `talosctl`.
3. Generate Talos config from `bootstrap/talos/`:

```bash
talhelper validate talconfig talconfig.yaml
talhelper genconfig
```

4. Apply and bootstrap Talos (single-node control plane example):

```bash
talosctl apply-config --insecure --nodes "${NODE_ADDRESS}" --file clusterconfig/arc-arc.yaml
talosctl bootstrap --nodes "${NODE_ADDRESS}" --endpoints "${NODE_ADDRESS}"
talosctl kubeconfig --nodes "${NODE_ADDRESS}" --endpoints "${NODE_ADDRESS}" --force
talosctl health --nodes "${NODE_ADDRESS}" --endpoints "${NODE_ADDRESS}"
kubectl -n flux-system get pods
```

5. Confirm Flux resources appear in `flux-system` and reconciliation begins.
6. Confirm Tuppr is running:

```bash
kubectl -n system-upgrade get pods
kubectl -n system-upgrade get talosupgrades,kubernetesupgrades
```

## Day-2 operations

### Health checks

```bash
talosctl health --nodes "${NODE_ADDRESS}" --endpoints "${NODE_ADDRESS}"
kubectl get nodes
kubectl -n flux-system get kustomizations,gitrepositories
kubectl -n system-upgrade get pods,talosupgrades,kubernetesupgrades
```

### Watch upgrade progress

```bash
kubectl -n system-upgrade get talosupgrade cluster -w
kubectl -n system-upgrade get kubernetesupgrade kubernetes -w
kubectl -n system-upgrade logs -f deployment/tuppr
```

### Suspend and resume upgrades

```bash
# suspend
kubectl -n system-upgrade annotate talosupgrade cluster tuppr.home-operations.com/suspend="true" --overwrite
kubectl -n system-upgrade annotate kubernetesupgrade kubernetes tuppr.home-operations.com/suspend="true" --overwrite

# resume
kubectl -n system-upgrade annotate talosupgrade cluster tuppr.home-operations.com/suspend-
kubectl -n system-upgrade annotate kubernetesupgrade kubernetes tuppr.home-operations.com/suspend-
```

### Reset failed upgrade state

```bash
kubectl -n system-upgrade annotate talosupgrade cluster tuppr.home-operations.com/reset="$(date +%s)" --overwrite
kubectl -n system-upgrade annotate kubernetesupgrade kubernetes tuppr.home-operations.com/reset="$(date +%s)" --overwrite
```

### Emergency stop (controller pause)

```bash
kubectl -n system-upgrade scale deployment tuppr --replicas=0
kubectl -n system-upgrade scale deployment tuppr --replicas=1
```

## Notes

- `bootstrap/talos/talconfig.yaml` uses a single `NODE_ADDRESS` value for both:
  - node target address (`nodes[].ipAddress`)
  - Talos API endpoint (`endpoint`)
- Bootstrap `talosVersion` and `kubernetesVersion` are pinned in `bootstrap/talos/talconfig.yaml` and managed by Renovate.
- `NODE_ADDRESS` can be either:
  - DNS name / FQDN (recommended)
  - static IP address
- Talos API access required by Tuppr is already included in `bootstrap/talos/talconfig.yaml` for control plane and worker machine configs.
- Tuppr Talos upgrades are tuned for single-node behavior in `infrastructure/upgrade/tuppr/talos-upgrade.yaml` (`placement: soft` + drain settings).
