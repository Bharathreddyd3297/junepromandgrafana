# Load injection guide

This guide injects six kinds of load into the demo pods and tells you where to see each one in Grafana and Prometheus. Finish the setup in the [README](../README.md) first.

All commands are the same in Bash and PowerShell unless two versions are shown.

## Before you start

1. Open Grafana and set the time range to **Last 15 minutes** with refresh **10s** (top right).
2. Keep these three browser tabs open:
   - Grafana dashboard **Lab 1 - Podinfo Application (RED metrics)**
   - Grafana dashboard **Lab 2 - Pod Resources and Load** (Namespace = `demo`)
   - Prometheus **Alerts** page
3. Check the starting state: `kubectl get pods -n demo` shows two `podinfo` pods, `2/2` ready.

**Timing to expect.** A change reaches the graphs in 15-45 seconds. An alert turns **Pending** shortly after that and **Firing** about 1 minute later, so allow 2-3 minutes per scenario.

## Summary

| # | Scenario | Start it with | Dashboard panel | Alert that fires |
|---|---|---|---|---|
| 1 | Normal traffic | scale `loadgen-ok` | Lab 1: Request rate | none |
| 2 | HTTP errors | scale `loadgen-errors` | Lab 1: Error rate (5xx %) | `PodinfoHighErrorRate` |
| 3 | Slow responses | scale `loadgen-slow` | Lab 1: Request duration percentiles | `PodinfoHighLatency` |
| 4 | CPU load in a pod | `cpu.py` in the stress container | Lab 2: CPU usage as % of limit, CPU throttling | `ContainerHighCpuUsage`, `ContainerCpuThrottling` |
| 5 | Memory load in a pod | `mem.py` in the stress container | Lab 2: Memory usage as % of limit | `ContainerHighMemoryUsage` |
| 6 | Out-of-memory kill | `mem.py` above the limit | Lab 2: Container restarts, OOM stat | `ContainerOOMKilled`, `ContainerRestarted` |
| 7 | Application outage | scale `podinfo` to 0 | Lab 1: Available replicas | `PodinfoNoTargets` |

## Scenario 1: Normal traffic

Start two traffic generators. Each sends about 20 requests per second to podinfo.

```bash
kubectl scale deployment/loadgen-ok -n demo --replicas=2
```

**Verify in Grafana (Lab 1)**

- **Request rate** rises from 0 to roughly 30-40 req/s.
- **Requests per second by HTTP status** shows a single band, `HTTP 200`.
- **Requests per second by pod** shows two lines of similar height: the Kubernetes Service is spreading traffic across both replicas.
- **Latency p95** stays in the low milliseconds.

**Verify in Prometheus (Query tab)**

```promql
demo:http_requests:rate1m
```

**Point to make:** the application publishes these numbers itself. Prometheus only collects them every 15 seconds.

Leave this running for scenarios 2 and 3 so there is healthy traffic to compare against.

## Scenario 2: HTTP errors

Add a generator whose requests all return HTTP 500.

```bash
kubectl scale deployment/loadgen-errors -n demo --replicas=2
```

**Verify in Grafana (Lab 1)**

- **Requests per second by HTTP status** gains a second band, `HTTP 500`.
- **Error rate (5xx %)** climbs above the red 5% threshold line, to roughly 30%.
- The **Error rate (5xx)** tile turns red.

**Verify in Prometheus**

```promql
demo:http_errors:ratio_rate1m
```

On the **Alerts** page, `PodinfoHighErrorRate` goes **Pending**, then **Firing** after 1 minute. Open Alertmanager to show that the alert arrived there with its summary and description.

**Stop it**

```bash
kubectl scale deployment/loadgen-errors -n demo --replicas=0
```

The error rate drops back to 0 and the alert resolves within about 2 minutes.

## Scenario 3: Slow responses

Add five clients whose requests each take 1 second.

```bash
kubectl scale deployment/loadgen-slow -n demo --replicas=1
```

**Verify in Grafana (Lab 1)**

- **Request duration percentiles**: p95 and p99 jump to about 1 second and cross the red 500 ms line. p50 stays low, because most requests are still fast.
- The **Latency p95** tile turns red.

**Verify in Prometheus**

```promql
demo:http_request_duration_seconds:p95_1m
```

`PodinfoHighLatency` goes **Pending**, then **Firing**.

**Point to make:** an average would hide this problem. Percentiles show that some users are having a bad experience while most are fine.

**Stop it**

```bash
kubectl scale deployment/loadgen-slow -n demo --replicas=0
```

## Scenario 4: CPU load inside a pod

Run a CPU burner inside one podinfo pod for 5 minutes. The arguments are seconds and number of worker processes.

```bash
kubectl exec -n demo deploy/podinfo -c stress -- python cpu.py 300 2
```

The command holds your terminal until it finishes. Use a second terminal for other commands. Pressing Ctrl+C returns your prompt but the load keeps running in the pod until its time is up.

**Verify in Grafana (Lab 2)**

- **CPU usage by container (cores)**: one `stress` line rises to 0.5 cores and goes flat. That flat top is the container's CPU limit (500m).
- **CPU usage as % of limit**: the same container reaches about 100%, above the red 80% line.
- **CPU throttling**: rises sharply. The workers want 2 cores but the limit allows half a core.
- The other pod's lines stay flat, which shows the problem is in one pod only.

**Verify in Prometheus**

```promql
demo:container_cpu_limit_utilisation:ratio
```

`ContainerHighCpuUsage` and `ContainerCpuThrottling` go **Pending**, then **Firing**.

**Load every podinfo pod at once**

```bash
for p in $(kubectl get pods -n demo -l app=podinfo -o name); do kubectl exec -n demo "$p" -c stress -- python cpu.py 300 2 & done; wait
```
```powershell
kubectl get pods -n demo -l app=podinfo -o name | ForEach-Object { Start-Process kubectl -ArgumentList "exec -n demo $_ -c stress -- python cpu.py 300 2" -WindowStyle Hidden }
```

Then open **Lab 3 - Cluster and Nodes Overview**: **Node CPU usage** and **CPU usage by namespace** both show the `demo` namespace's extra load.

## Scenario 5: Memory load inside a pod

Allocate 220 MiB inside one pod and hold it for 5 minutes. The stress container's limit is 256 MiB.

```bash
kubectl exec -n demo deploy/podinfo -c stress -- python mem.py 220 300
```

**Verify in Grafana (Lab 2)**

- **Memory working set by container**: one `stress` line steps up to about 230 MiB.
- **Memory usage as % of limit**: about 90%, above the red 80% line.

**Verify in Prometheus**

```promql
demo:container_memory_limit_utilisation:ratio
```

`ContainerHighMemoryUsage` goes **Pending**, then **Firing**.

**Point to make:** this alert is an early warning. It fires while the container is still running, before Kubernetes kills it.

## Scenario 6: Out-of-memory kill

Ask for 400 MiB, well above the 256 MiB limit.

```bash
kubectl exec -n demo deploy/podinfo -c stress -- python mem.py 400 60
```

The command ends with exit code 137: the kernel killed it for exceeding the memory limit.

**Verify with kubectl**

```bash
kubectl get pods -n demo
```

On current AKS versions the whole `stress` container is restarted, so one podinfo pod shows `RESTARTS 1`. `kubectl describe pod <name> -n demo` shows `Last State: Terminated, Reason: OOMKilled`. If the restart count stays at 0, only the process was killed; the memory graph still shows the spike and the sudden drop.

**Verify in Grafana (Lab 2)**

- **Memory working set by container**: a climb followed by a sudden drop.
- **Container restarts**: steps up by 1.
- **Containers last killed by OOM** tile shows 1 and turns red.

`ContainerOOMKilled` and `ContainerRestarted` fire immediately (these rules have no waiting period) and clear by themselves after 5-10 minutes.

## Scenario 7: Application outage

Stop the application completely.

```bash
kubectl scale deployment/podinfo -n demo --replicas=0
```

**Verify**

- Grafana Lab 1: **Available replicas** drops to 0 and turns red. Request panels go empty.
- Prometheus **Status > Target health**: the podinfo targets disappear.
- `PodinfoNoTargets` goes **Pending**, then **Firing** after 1 minute.

**Point to make:** monitoring has to detect missing data as well as bad data. A dashboard with no line on it is easy to miss, so this alert uses `absent()` to fire when the metric itself is gone.

**Restore it**

```bash
kubectl scale deployment/podinfo -n demo --replicas=2
```

## Stop all load

```bash
kubectl scale deployment -n demo -l app=loadgen --replicas=0
kubectl scale deployment/podinfo -n demo --replicas=2
```

CPU and memory load stop by themselves when their timer ends. To stop them immediately, restart the pods:

```bash
kubectl rollout restart deployment/podinfo -n demo
```

## Queries worth showing in the Prometheus UI

| Question | PromQL |
|---|---|
| Is every podinfo pod being scraped? | `up{namespace="demo"}` |
| Requests per second by status code | `sum by (status) (rate(http_request_duration_seconds_count{namespace="demo"}[1m]))` |
| p99 latency | `histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{namespace="demo"}[1m])))` |
| CPU cores used per pod | `sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="demo", container!=""}[2m]))` |
| Memory per pod | `sum by (pod) (container_memory_working_set_bytes{namespace="demo", container!=""})` |
| Restarts per container | `kube_pod_container_status_restarts_total{namespace="demo"}` |
| Alerts firing now | `ALERTS{alertstate="firing"}` |

## Suggested 15-minute demo order

1. Show the Prometheus **Target health** page and one raw query (`up{namespace="demo"}`). 2 min
2. Scenario 1, on the Lab 1 dashboard. 2 min
3. Scenario 2: watch the alert go Pending then Firing, and show it in Alertmanager. 3 min
4. Scenario 4, on the Lab 2 dashboard: usage flattens at the limit and throttling rises. 3 min
5. Scenario 6: the OOM kill and the restart counter. 3 min
6. Lab 3 dashboard for the cluster view, then stop all load. 2 min
