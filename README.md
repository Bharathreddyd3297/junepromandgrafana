# Prometheus and Grafana on AKS: 15-minute demo lab

This lab builds a 2-node AKS cluster, installs Prometheus, Alertmanager and Grafana, deploys a demo application that exposes metrics, and gives you dashboards, alert rules and load scenarios to demonstrate.

| Step | What happens | Typical time |
|---|---|---|
| 1 | Create the AKS cluster and connect to it | 5-6 min |
| 2 | Install Prometheus, Alertmanager and Grafana (Helm) | 2-3 min |
| 3 | Deploy the demo app and the custom Prometheus rules | 1 min |
| 4 | Open Grafana and Prometheus from your laptop | 1-2 min |
| 5 | Import the dashboards | 2 min |

After setup, continue with:

- [docs/load-injection-guide.md](docs/load-injection-guide.md): inject load into the pods and verify it in Grafana
- [docs/why-prometheus-grafana.md](docs/why-prometheus-grafana.md): talking points on why Prometheus and Grafana matter

## What is in this folder

```
README.md                         this guide
docs/
  load-injection-guide.md         load scenarios and what to check in Grafana
  why-prometheus-grafana.md       talking points for the discussion
scripts/                          every step as a script, in bash (.sh) and PowerShell (.ps1)
manifests/
  monitoring-values.yaml          Helm values for kube-prometheus-stack
  monitoring-values-loadbalancer.yaml   optional: expose the UIs on public IPs
  demo-app.yaml                   podinfo app, stress sidecar, load generators, ServiceMonitor
  prometheus-rules.yaml           recording rules and alerts
dashboards/                       three Grafana dashboards to import (JSON)
```

## Prerequisites

You need an Azure subscription where you can create a resource group and an AKS cluster.

**Option A: Azure Cloud Shell (Bash).** `az`, `kubectl` and `helm` are already installed. Zip this folder, upload it with **Manage files > Upload**, and run `unzip <file>.zip`. Port-forwarding does not reach your laptop from Cloud Shell, so use the load balancer option in step 4.

**Option B: your laptop.** Install the three tools, then sign in:

```powershell
winget install Microsoft.AzureCLI
winget install Helm.Helm
az aks install-cli        # installs kubectl
az login
az account set --subscription "<subscription name or id>"   # only if you have several
```

Run every command below from this folder (the one that contains `README.md`).

## Step 1: Create the AKS cluster and connect to it

**Script**

```bash
./scripts/01-create-aks.sh          # Cloud Shell, Git Bash, Linux, macOS
```
```powershell
.\scripts\01-create-aks.ps1         # Windows PowerShell
```

If PowerShell refuses to run scripts, start it with `powershell -ExecutionPolicy Bypass` and try again.

**Or run the commands yourself** (they are the same in Bash and PowerShell):

```bash
az group create --name rg-promgraf-lab --location eastus

az aks create --resource-group rg-promgraf-lab --name aks-promgraf-lab --node-count 2 --node-vm-size Standard_D2s_v3 --tier free --generate-ssh-keys

az aks get-credentials --resource-group rg-promgraf-lab --name aks-promgraf-lab --overwrite-existing

kubectl get nodes
```

You should see two nodes in `Ready` state. `az aks get-credentials` is the step that connects `kubectl` (in Cloud Shell or on your laptop) to the cluster: it merges the cluster's credentials into `~/.kube/config`.

To use another region or VM size, set `LOCATION` or `NODE_SIZE` before running the script (for example `export LOCATION=centralindia`, or `$env:LOCATION = 'centralindia'` in PowerShell). If `Standard_D2s_v3` is not available in your subscription, any size with 2 vCPUs and 8 GB works, such as `Standard_D2as_v5` or `Standard_B2ms`.

## Step 2: Install Prometheus, Alertmanager and Grafana

**Script**

```bash
./scripts/02-install-monitoring.sh
```
```powershell
.\scripts\02-install-monitoring.ps1
```

**Or run the commands yourself**

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace --values manifests/monitoring-values.yaml --wait --timeout 10m

kubectl get pods -n monitoring
```

One chart, `kube-prometheus-stack`, installs all of this:

| Component | Role |
|---|---|
| Prometheus Operator | Manages Prometheus through Kubernetes objects (`ServiceMonitor`, `PrometheusRule`) |
| Prometheus | Scrapes and stores metrics, evaluates rules |
| Alertmanager | Receives firing alerts, groups them and routes them |
| Grafana | Dashboards, with Prometheus already configured as the data source |
| node-exporter | Node metrics: CPU, memory, disk, network |
| kube-state-metrics | Kubernetes object state: deployments, pods, restarts, limits |

[manifests/monitoring-values.yaml](manifests/monitoring-values.yaml) sets a 15-second scrape interval so changes show up quickly, lets Prometheus pick up monitors and rules from every namespace, and turns off scraping of control-plane components that AKS manages and hides.

## Step 3: Deploy the demo app and the Prometheus rules

**Script**

```bash
./scripts/03-deploy-app.sh
```
```powershell
.\scripts\03-deploy-app.ps1
```

**Or run the commands yourself**

```bash
kubectl apply -f manifests/demo-app.yaml
kubectl apply -f manifests/prometheus-rules.yaml
kubectl rollout status deployment/podinfo -n demo
kubectl get pods -n demo
```

You should see two `podinfo` pods with `2/2` containers ready. [manifests/demo-app.yaml](manifests/demo-app.yaml) creates:

- **podinfo**: a small web application (2 replicas) that publishes request counts and latencies on `/metrics`.
- **stress sidecar**: a second container in each podinfo pod, used to inject CPU and memory load.
- **loadgen-ok, loadgen-errors, loadgen-slow**: HTTP traffic generators that start at 0 replicas. You scale them up to inject traffic.
- **ServiceMonitor**: the object that tells Prometheus to scrape podinfo every 15 seconds.

## Step 4: Open Grafana and Prometheus from your laptop

### Option A: port-forward (laptop only)

```bash
./scripts/04-port-forward.sh
```
```powershell
.\scripts\04-port-forward.ps1
```

Leave it running and open:

| UI | URL |
|---|---|
| Grafana | http://localhost:3000 |
| Prometheus | http://localhost:9090 |
| Alertmanager | http://localhost:9093 |
| Demo app | http://localhost:9898 |

The manual equivalent is one terminal per command:

```bash
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-alertmanager 9093:9093
```

### Option B: Azure load balancer (works from Cloud Shell too)

Find your laptop's public IP by opening https://ifconfig.me in a browser, then:

```bash
./scripts/05-expose-loadbalancer.sh <your-public-ip>
```
```powershell
.\scripts\05-expose-loadbalancer.ps1 <your-public-ip>
```

The script prints the three public URLs after 1-2 minutes. Access is limited to the IP you pass, because Prometheus and Alertmanager have no login. Passing `any` instead of an IP opens them to the internet; do that only for a short demo and delete the cluster afterwards.

### Grafana login

- User: `admin`
- Password: `PromGraf-Lab-2026` (set in [manifests/monitoring-values.yaml](manifests/monitoring-values.yaml); change it there before step 2 if you plan to use option B)

## Step 5: Check that everything is connected

In **Prometheus**:

1. **Status > Target health** (called **Targets** in older versions): `serviceMonitor/demo/podinfo/0` shows 2 targets, both `UP`.
2. **Alerts**: the groups `demo.app.alerts`, `demo.resources.alerts` and `demo.node.alerts` are listed, all inactive (green).
3. **Query**: run `up{namespace="demo"}`. It returns one series per podinfo pod with value `1`.

In **Grafana**: **Dashboards** already lists about 25 dashboards shipped with the chart, for example *Kubernetes / Compute Resources / Namespace (Pods)* and *Node Exporter / Nodes*.

## Step 6: Import the lab dashboards

| File | Dashboard | Shows |
|---|---|---|
| [dashboards/01-podinfo-app-red.json](dashboards/01-podinfo-app-red.json) | Lab 1 - Podinfo Application (RED metrics) | Request rate, error rate, latency percentiles, traffic per pod |
| [dashboards/02-pod-resources-load.json](dashboards/02-pod-resources-load.json) | Lab 2 - Pod Resources and Load | CPU and memory per container against limits, throttling, restarts, OOM kills |
| [dashboards/03-cluster-nodes-overview.json](dashboards/03-cluster-nodes-overview.json) | Lab 3 - Cluster and Nodes Overview | Node CPU, memory and disk, pods per node, usage per namespace, firing alerts |

**Import through the UI** (repeat for each file):

1. In Grafana, open **Dashboards > New > Import**.
2. Choose **Upload dashboard JSON file** and pick the file.
3. Select **Import**. The data source is picked automatically.

**Or load all three with kubectl.** Grafana watches for ConfigMaps labelled `grafana_dashboard=1` and loads them within a minute:

```bash
kubectl create configmap lab-dashboards -n monitoring --from-file=dashboards
kubectl label configmap lab-dashboards -n monitoring grafana_dashboard=1
```

Use one method or the other. The dashboards have fixed IDs, so importing a file that was already loaded the other way reports a conflict.

You can also import community dashboards by ID in the same Import screen, for example `1860` (*Node Exporter Full*).

## Step 7: The Prometheus rules

[manifests/prometheus-rules.yaml](manifests/prometheus-rules.yaml) is a `PrometheusRule` object. The operator loads it into Prometheus automatically; you can see it under **Alerts** and **Status > Rule health** in Prometheus.

**Recording rules** pre-compute a query and store the result as a new metric, so dashboards and alerts stay fast and simple:

| New metric | Meaning |
|---|---|
| `demo:http_requests:rate1m` | Requests per second to podinfo |
| `demo:http_errors:ratio_rate1m` | Share of requests that returned HTTP 5xx |
| `demo:http_request_duration_seconds:p95_1m` | 95th percentile request duration |
| `demo:container_cpu_limit_utilisation:ratio` | CPU usage as a share of the container's limit |
| `demo:container_memory_limit_utilisation:ratio` | Memory usage as a share of the container's limit |

**Alerting rules** fire when a condition stays true for the `for` duration:

| Alert | Fires when | Severity |
|---|---|---|
| `PodinfoHighErrorRate` | More than 5% of requests fail for 1 minute | critical |
| `PodinfoHighLatency` | p95 latency above 500 ms for 1 minute | warning |
| `PodinfoTargetDown` | Prometheus cannot scrape a podinfo pod for 1 minute | critical |
| `PodinfoNoTargets` | No podinfo targets exist for 1 minute | critical |
| `PodinfoReplicasMismatch` | Fewer replicas available than desired for 1 minute | warning |
| `ContainerHighCpuUsage` | A container uses more than 80% of its CPU limit for 1 minute | warning |
| `ContainerCpuThrottling` | More than 25% of CPU periods are throttled for 1 minute | warning |
| `ContainerHighMemoryUsage` | A container uses more than 80% of its memory limit for 1 minute | warning |
| `ContainerOOMKilled` | A container was killed for exceeding its memory limit | critical |
| `ContainerRestarted` | A container restarted in the last 5 minutes | warning |
| `NodeHighCpuUsage` | Node CPU above 80% for 2 minutes | warning |
| `NodeHighMemoryUsage` | Node memory above 85% for 2 minutes | warning |

The `for` durations are short on purpose so that alerts fire during a live demo. Production rules usually wait 5-15 minutes to avoid noise.

An alert moves through three states that you can show in the Prometheus **Alerts** page: **Inactive** (condition false), **Pending** (condition true, waiting for the `for` duration), **Firing** (sent to Alertmanager).

To change a rule, edit the file and run `kubectl apply -f manifests/prometheus-rules.yaml` again. Prometheus reloads it in under a minute.

## Step 8: Inject load and watch the dashboards

Follow [docs/load-injection-guide.md](docs/load-injection-guide.md).

## Step 9: Clean up

The cluster costs money while it runs. Delete everything when you are done:

```bash
./scripts/99-cleanup.sh
```
```powershell
.\scripts\99-cleanup.ps1 -Yes
```

Or: `az group delete --name rg-promgraf-lab --yes --no-wait`

## Troubleshooting

| Symptom | Check |
|---|---|
| `az aks create` fails with a quota or SKU error | Use another size or region: set `NODE_SIZE` or `LOCATION` and re-run step 1 |
| Helm install times out | `kubectl get pods -n monitoring` and `kubectl describe pod <name> -n monitoring`; re-running step 2 is safe |
| podinfo target missing in Prometheus | `kubectl get servicemonitor -n demo`; wait one minute after step 3 |
| Lab dashboards show "No data" | Confirm the podinfo target is `UP`; the request panels stay empty until you start a load generator |
| Port-forward stops | It drops when a pod restarts or the connection idles; run the step 4 script again |
| Rules not listed in Prometheus | `kubectl get prometheusrule -n demo`; `kubectl logs -n monitoring deploy/monitoring-kube-prometheus-operator` shows rejected rules |
