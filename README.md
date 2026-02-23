# VictoriaMetrics Kubernetes Mixins Demo

This project demonstrates how to use [Kubernetes Mixins](https://github.com/kubernetes-monitoring/kubernetes-mixin) with the [VictoriaMetrics Operator](https://github.com/VictoriaMetrics/operator) stack. It accompanies the blog post: [VictoriaMetrics observability from day one](/driv.github.io/_posts/2026-02-10-victoriametrics-mixins.markdown).

It includes a fully reproducible local environment using [Kind](https://kind.sigs.k8s.io/).

## Prerequisites

- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)
- [Helmfile](https://github.com/helmfile/helmfile)
- [Jsonnet](https://jsonnet.org/) (for generating mixins)
- [jb](https://github.com/jsonnet-bundler/jsonnet-bundler) (Jsonnet Bundler)

## Quick Start

### 1. Create Kind Cluster

Create a new cluster. 

```bash
kind create cluster --name vm-monitoring
```

### 2. Patch Control Plane (Crucial for Kind)

Kind isolates control plane components (Controller Manager, Scheduler, Etcd) on the host network of the control-plane container, listening on `127.0.0.1` by default. This makes them inaccessible to the `vmagent` pod running inside the cluster.

We must patch them to listen on `0.0.0.0` and expose `kube-proxy` metrics.

```bash
# 1. Bind Controller Manager and Scheduler to 0.0.0.0
docker exec vm-monitoring-control-plane sed -i 's/--bind-address=127.0.0.1/--bind-address=0.0.0.0/' /etc/kubernetes/manifests/kube-controller-manager.yaml
docker exec vm-monitoring-control-plane sed -i 's/--bind-address=127.0.0.1/--bind-address=0.0.0.0/' /etc/kubernetes/manifests/kube-scheduler.yaml

# 2. Bind Etcd metrics to 0.0.0.0
docker exec vm-monitoring-control-plane sed -i 's/--listen-metrics-urls=http:\/\/127.0.0.1:2381/--listen-metrics-urls=http:\/\/0.0.0.0:2381/' /etc/kubernetes/manifests/etcd.yaml

# 3. Expose Kube Proxy metrics (listen on all interfaces)
kubectl -n kube-system get cm kube-proxy -o yaml | sed 's/metricsBindAddress: ""/metricsBindAddress: "0.0.0.0:10249"/' | kubectl apply -f -
kubectl -n kube-system delete pod -l k8s-app=kube-proxy

# 4. Wait for control plane to restart and be ready
sleep 15
kubectl -n kube-system wait --for=condition=Ready pods -l tier=control-plane --timeout=120s
```

### 3. Install VictoriaMetrics Stack

We use `helmfile` to install the `victoria-metrics-k8s-stack`. This chart includes VictoriaMetrics (single node), vmagent, vmalert, and Grafana.

> **Note:** The `helmfile.yaml` in this repo includes specific overrides (`insecureSkipVerify`, `bearerTokenFile`, `http` for etcd) required to scrape the Kind control plane components successfully.

```bash
helmfile sync
```

### 4. Generate and Apply Mixins

We use `jsonnet` to generate the alerts, recording rules, and dashboards from the `kubernetes-mixin` project, adapted for VictoriaMetrics.

```bash
# Install dependencies
jb install

# Generate the Kubernetes manifests (VMRule, ConfigMap)
# k8s.libsonnet wraps the raw mixin output into VM-compatible resources
jsonnet -J vendor k8s.libsonnet > manifests.yaml

# Apply to the cluster
kubectl apply -f manifests.yaml
```

### 5. Access Grafana

Port-forward the Grafana service:

```bash
kubectl port-forward -n monitoring svc/grafana 3000:80
```

Open [http://localhost:3000](http://localhost:3000) in your browser.
- **User:** `admin`
- **Password:** `prom-operator` (default for the chart)

You should see:
- A rich set of Kubernetes dashboards (Compute Resources, Networking, etc.).
- Active alerts in the Alerting section (likely only `Watchdog` firing, which is good!).

## Repository Structure

- `main.libsonnet`: Configuration overrides for the `kubernetes-mixin` to match VictoriaMetrics job names.
- `k8s.libsonnet`: Wrapper to package the generated JSON into `VMRule` and `ConfigMap` resources.
- `helmfile.yaml`: Configuration for deploying the VictoriaMetrics stack on Kind.