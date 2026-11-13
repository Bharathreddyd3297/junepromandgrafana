# Why Prometheus and Grafana matter

Talking points for the discussion part of the demo. Each section can stand alone, so use the ones that fit your time.

## The problem they solve

Kubernetes makes applications harder to observe by hand:

- **Pods are short-lived.** They are rescheduled, scaled and replaced, and their names and IPs change each time. A monitoring tool that needs a fixed list of servers cannot keep up.
- **There are many layers.** A slow request may be caused by the application, its container limits, the node, or the cluster. You need metrics from all of them in one place.
- **Kubernetes hides failures.** It restarts crashed containers automatically. Without monitoring, an application can crash every few minutes and nobody notices until users complain.
- **`kubectl top` shows only the present.** It has no history, no trends and no alerts.

Monitoring answers three questions: Is it working? If not, where is the problem? Will it still work next week?

## What each tool does

| | Prometheus | Grafana |
|---|---|---|
| Role | Collects, stores and evaluates metrics | Visualises metrics |
| Core feature | Time-series database with the PromQL query language | Dashboards, variables, sharing |
| Alerting | Evaluates alert rules and sends them to Alertmanager | Can also alert, and shows alert state |
| Data | Stores its own | Stores none; it queries data sources |

They do different jobs and work best together: Prometheus is the data and the logic, Grafana is the view that people look at.

## How Prometheus works

```
  Applications        node-exporter       kube-state-metrics      kubelet / cAdvisor
  (/metrics)          (node CPU, disk)    (pods, deployments)     (container CPU, memory)
        \                   |                     |                      /
         \------------------+----- scrape (pull) -+---------------------/
                                      |
                                 Prometheus  ---- alert rules ---->  Alertmanager ---> email, Teams,
                              (time-series DB)                                         Slack, PagerDuty
                                      |
                                   PromQL
                                      |
                                   Grafana  --->  dashboards
```

- **Pull model.** Prometheus calls each target's `/metrics` endpoint on a schedule (every 15 seconds in this lab). A target that does not answer is itself a signal: the `up` metric becomes 0.
- **Service discovery.** Prometheus asks the Kubernetes API which pods exist, so new pods are monitored automatically and deleted pods are dropped. In this lab the `ServiceMonitor` object does this for podinfo.
- **Labels.** Every metric carries labels such as `namespace`, `pod` and `status`. You can slice the same metric by any of them without planning it in advance.
- **PromQL.** A query language built for time series: rates, percentiles, ratios and aggregations in one line.
- **Exporters.** Small programs that translate other systems into Prometheus metrics. There are exporters for Linux nodes, databases, message queues, load balancers and hundreds more.
- **Rules.** Recording rules pre-compute expensive queries. Alerting rules decide when a human needs to know.
- **Alertmanager.** Groups related alerts, removes duplicates, silences alerts during maintenance and routes them to the right team.

### The four metric types

| Type | Meaning | Example from the lab |
|---|---|---|
| Counter | Only goes up; you look at its rate | `http_request_duration_seconds_count` |
| Gauge | Goes up and down | `container_memory_working_set_bytes` |
| Histogram | Counts observations in buckets; gives percentiles | `http_request_duration_seconds_bucket` |
| Summary | Percentiles calculated by the application | less common |

## Why Grafana

- **One screen for many sources.** Prometheus, Azure Monitor, Loki, Elasticsearch, SQL databases and others can sit side by side on one dashboard.
- **Dashboards are shared knowledge.** A good dashboard records what the team has learned about what matters. New team members read the system from it.
- **Variables.** One dashboard serves every namespace, pod or environment through drop-downs, as in the Lab 2 dashboard.
- **Dashboards as code.** Dashboards are JSON. They can be stored in Git, reviewed and deployed automatically, as with the files in this lab.
- **Large community.** Thousands of ready-made dashboards can be imported by ID from grafana.com.

## What to measure

Two short methods cover most needs. The lab dashboards follow them.

**RED, for services (what users feel)**: Lab 1 dashboard

- **R**ate: requests per second
- **E**rrors: failed requests
- **D**uration: how long requests take

**USE, for resources (what the infrastructure feels)**: Lab 2 and Lab 3 dashboards

- **U**tilisation: how much of the resource is used (CPU % of limit)
- **S**aturation: how much work is waiting (CPU throttling)
- **E**rrors: failures (OOM kills, restarts)

Google's "four golden signals" (latency, traffic, errors, saturation) combine the same ideas.

## Benefits for the business

- **Faster detection.** Alerts arrive before users report a problem. In the lab, the memory alert fires at 80% of the limit, before the container is killed.
- **Faster diagnosis.** Dashboards narrow a problem from the cluster to a node, a pod and a container in a few clicks, instead of logging into machines.
- **Right-sizing and cost.** Usage compared with requests and limits shows which workloads are over-provisioned and which are throttled.
- **Capacity planning.** History shows growth trends, so nodes are added before they run out.
- **Evidence for decisions.** Service level objectives, release comparisons and autoscaling are all built on metrics.
- **No licence cost and no lock-in.** Both tools are open source. Prometheus is a graduated CNCF project, the same foundation that hosts Kubernetes, and its metric format is supported by most cloud-native software.

## Why they are the standard for Kubernetes

- Kubernetes components expose Prometheus metrics natively: the API server, kubelet and CoreDNS all have `/metrics` endpoints.
- The Prometheus Operator lets you manage monitoring with Kubernetes objects (`ServiceMonitor`, `PrometheusRule`), deployed the same way as applications.
- Autoscaling can use Prometheus metrics (for example through KEDA or the Prometheus adapter).
- Skills transfer: the same tools and queries work on AKS, EKS, GKE and on-premises clusters.

## Limits to be honest about

- **Metrics only.** Prometheus does not store logs or traces. Pair it with a logging tool (Loki, Azure Monitor Logs, Elasticsearch) and tracing (Tempo, Jaeger).
- **Single-node storage.** One Prometheus server keeps data on local disk, typically for days or weeks. Long retention or a global view across many clusters needs Thanos, Mimir or a managed service.
- **It needs care.** Someone has to size it, upgrade it and watch its own health.
- **Label cardinality.** Labels with unbounded values, such as user IDs, create huge numbers of series and can exhaust memory.

## Self-managed or managed on Azure

| | Self-managed (this lab) | Azure Monitor managed service for Prometheus + Azure Managed Grafana |
|---|---|---|
| Setup | Helm chart in the cluster | Enabled on the AKS cluster |
| Operations | You run and upgrade it | Microsoft runs it |
| Retention | Limited by cluster disk | Long retention in an Azure Monitor workspace |
| Cost | Cluster compute and disk | Pay for metrics ingested and queried |
| Access control | Grafana users | Microsoft Entra ID |
| Good for | Learning, full control, portability | Production with less operational work |

The queries, rules and dashboards are the same in both, so what you learn in this lab carries over.

## One-sentence summary

Prometheus tells you what is happening and warns you when it goes wrong; Grafana lets everyone see it.
