+++
title = "The Observability Gap with kube-prometheus-stack in Kubernetes"
description = "Kubernetes observability goes beyond Prometheus Grafana monitoring. Learn why kube-prometheus-stack falls short and how to bridge the gap."
date = "2025-10-05"
author = "Fatih Koç"
tags = ["Kubernetes", "Observability", "Prometheus", "Grafana", "Monitoring", "DevOps"]
images = ["/images/monitoring-kube-prometheus-stack/observability-gap-kubernetes.webp"]
featuredImage = "/images/monitoring-kube-prometheus-stack/observability-gap-kubernetes.webp"
+++

Observability in Kubernetes has become a hot topic in recent years. Teams everywhere deploy the popular **kube-prometheus-stack**, which bundles Prometheus and Grafana into an opinionated setup for monitoring Kubernetes workloads. On the surface, it looks like the answer to all your monitoring needs. But here is the catch: **monitoring is not observability**. And if you confuse the two, you will hit a wall when your cluster scales or your incident response gets messy.

In this first post of my observability series, I want to break down the real difference between monitoring and observability, highlight the gaps in kube-prometheus-stack, and suggest how we can move toward true Kubernetes observability.

## The question I keep hearing

I worked with a team running microservices on Kubernetes. They had kube-prometheus-stack deployed, beautiful Grafana dashboards, and alerts configured. Everything looked great until 3 AM on a Tuesday when API requests started timing out.

The on-call engineer got paged. Prometheus showed CPU spikes. Grafana showed pod restarts. When the team jumped on Slack, they asked me: "Do you have tools for understanding what causes these timeouts?" They spent two hours manually correlating logs across CloudWatch, checking recent deployments, and guessing at database queries before finding the culprit: a batch job with an unoptimized query hammering the production database.

I had seen this pattern before. Their monitoring stack told them something was broken, but not why. With distributed tracing, they would have traced the slow requests back to that exact query in minutes, not hours. This is the observability gap I keep running into: teams confuse monitoring dashboards with actual observability. The lesson for them was clear: monitoring answers "what broke" while observability answers "why it broke." And fixing this requires shared ownership. Developers need to instrument their code for visibility. DevOps engineers need to provide the infrastructure to capture and expose that behavior. When both sides own observability together, incidents get resolved faster and systems become more reliable.

## Monitoring vs Observability

Most engineers use the terms interchangeably, but they are not the same. Monitoring tells you when something is wrong, while observability helps you understand why it went wrong.

* **Monitoring**: Answers "what is happening?" You collect predefined metrics (CPU, memory, disk) and set alerts when thresholds are breached. Your alert fires: "CPU usage is 95%." Now what?
* **Observability**: Answers "why is this happening?" You investigate using interconnected data you didn't know you'd need. Which pod is consuming CPU? What user request triggered it? Which database query is slow? What changed in the last deployment?

The classic definition of observability relies on the **three pillars**:

* **Metrics**: Numerical values over time (CPU, latency, request counts).
* **Logs**: Unstructured text for contextual events.
* **Traces**: Request flow across services.

Prometheus and Grafana excel at metrics, but Kubernetes observability requires all three pillars working together. The [CNCF observability landscape](https://landscape.cncf.io/guide#observability-and-analysis--observability) shows how the ecosystem has evolved beyond simple monitoring. If you only deploy kube-prometheus-stack, you will only get one piece of the puzzle.

## The Dominance of kube-prometheus-stack

Let's be fair. kube-prometheus-stack is the default for a reason. It provides:

* **Prometheus** for metrics scraping
* **Grafana** for dashboards
* **Alertmanager** for rule-based alerts
* **Node Exporter** for hardware and OS metrics

With Helm, you can set it up in minutes. This is why it dominates Kubernetes monitoring setups today. But it's not the full story.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

Within minutes, you'll have Prometheus scraping metrics, Grafana running on port 3000, and a collection of pre-configured dashboards. It feels like magic at first.

Access Grafana to see your dashboards:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

Default credentials are `admin` / `prom-operator`. You'll immediately see dashboards for Kubernetes cluster monitoring, node exporter metrics, and pod resource usage. The data flows in automatically.

In many projects, I've seen teams proudly display dashboards full of red and green panels yet still struggle during incidents. Why? Because the dashboards told them *what* broke, not *why*. 

## Common Pitfalls with kube-prometheus-stack

### Metric Cardinality Explosion

**Cardinality** is the number of unique time series created by combining a metric name with all possible label value combinations. Each unique combination creates a separate time series that Prometheus must store and query. The [Prometheus documentation on metric and label naming](https://prometheus.io/docs/practices/naming/) provides official guidance on avoiding cardinality issues.

Prometheus loves labels, but too many labels can crash your cluster. If you add dynamic labels like `user_id` or `transaction_id`, you end up with **millions of time series**. This causes both storage and query performance issues. I've witnessed a production cluster go down not because of the application but because Prometheus itself was choking.

Here's a bad example that will destroy your Prometheus instance:

```python
from prometheus_client import Counter

# BAD: High cardinality labels
http_requests = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'user_id', 'transaction_id']  # AVOID!
)

# With 1000 users and 10000 transactions per user, you get:
# 5 methods * 20 endpoints * 1000 users * 10000 transactions = 1 billion time series
```

Instead, use low-cardinality labels and track high-cardinality data elsewhere:

```python
from prometheus_client import Counter

# GOOD: Low cardinality labels
http_requests = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status_code']  # Limited set of values
)

# Now you have: 5 methods * 20 endpoints * 5 status codes = 500 time series
```

You can check your cardinality with this PromQL query:

```promql
count({__name__=~".+"}) by (__name__)
```

If you see metrics with hundreds of thousands of series, you've found your culprit.

### Lack of Scalability

In small clusters, a single Prometheus instance works fine. In large enterprises with multiple clusters, it becomes a nightmare. Without federation or sharding, Prometheus does not scale well. If you're building multi-cluster infrastructure, understanding [Kubernetes deployment patterns](/posts/k8s-deployment-guide/) becomes critical for running monitoring components reliably.

For multi-cluster setups, you'll need Prometheus federation according to the [Prometheus federation documentation](https://prometheus.io/docs/prometheus/latest/federation/). Here's a basic configuration for a global Prometheus instance that scrapes from cluster-specific instances:

```yaml
scrape_configs:
  - job_name: 'federate'
    scrape_interval: 15s
    honor_labels: true
    metrics_path: '/federate'
    params:
      'match[]':
        - '{job="kubernetes-pods"}'
        - '{__name__=~"job:.*"}'
    static_configs:
      - targets:
        - 'prometheus-cluster-1.monitoring:9090'
        - 'prometheus-cluster-2.monitoring:9090'
        - 'prometheus-cluster-3.monitoring:9090'
```

Even with federation, you hit storage limits. A single Prometheus instance struggles beyond 10-15 million active time series.

### Alert Fatigue

Kube-prometheus-stack ships with a bunch of default alerts. While they are useful at first, they quickly generate **alert fatigue**. Engineers drown in notifications that don't actually help them resolve issues.

Check your current alert rules:

```bash
kubectl get prometheusrules -n monitoring
```

You'll likely see dozens of pre-configured alerts. Here's an example of a noisy alert that fires too often:

```yaml
- alert: KubePodCrashLooping
  annotations:
    description: 'Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash looping'
    summary: Pod is crash looping.
  expr: |
    max_over_time(kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"}[5m]) >= 1
  for: 15m
  labels:
    severity: warning
```

The problem? This fires for every pod in CrashLoopBackOff, including those in development namespaces or expected restarts during deployments. You end up with alert spam.

A better approach is to tune alerts based on criticality:

```yaml
- alert: CriticalPodCrashLooping
  annotations:
    description: 'Critical pod {{ $labels.namespace }}/{{ $labels.pod }} is crash looping'
    summary: Production-critical pod is failing.
  expr: |
    max_over_time(kube_pod_container_status_waiting_reason{
      reason="CrashLoopBackOff",
      namespace=~"production|payment|auth"
    }[5m]) >= 1
  for: 5m
  labels:
    severity: critical
```

Now you only get alerted for crashes in critical namespaces, and you can respond faster because the signal-to-noise ratio is higher.

### Dashboards That Show What but Not Why

Grafana panels look impressive, but most of them only highlight symptoms. High CPU, failing pods, dropped requests. They don't explain the underlying cause. This is the observability gap.

Here's a typical PromQL query you'll see in Grafana dashboards:

```promql
# Shows CPU usage percentage
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

This tells you **what**: CPU is at 95%. But it doesn't tell you **why**. Which process? Which pod? What triggered the spike?

You can try drilling down with more queries:

```promql
# Top 10 pods by CPU usage
topk(10, rate(container_cpu_usage_seconds_total[5m]))
```

Even this shows you the pod name, but not the request path, user action, or external dependency that caused the spike. Without distributed tracing, you're guessing. You end up in Slack asking, "Did anyone deploy something?" or "Is the database slow?"

## Why kube-prometheus-stack Alone Is Not Enough for Kubernetes Observability

Here is the opinionated part: kube-prometheus-stack is **monitoring, not observability**. It’s a foundation, but not the endgame. Kubernetes observability requires:

* **Logs** (e.g., Loki, Elasticsearch)
* **Traces** (e.g., Jaeger, Tempo)
* **Correlated context** (not isolated metrics)

Without these, you will continue firefighting with partial visibility.

## Building a Path Toward Observability

So, how do we close the observability gap?

* Start with kube-prometheus-stack, but **acknowledge its limits**.
* Add a **centralized logging solution** (Loki, Elasticsearch, or your preferred stack).
* Adopt **distributed tracing** with Jaeger or Tempo.
* Prepare for the next step: **OpenTelemetry**.

Here's how to add Loki for centralized logging alongside your existing Prometheus setup:

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Loki for log aggregation
helm install loki grafana/loki \
  --namespace monitoring \
  --create-namespace
```

For distributed tracing, Tempo integrates seamlessly with Grafana:

```bash
# Install Tempo for traces
helm install tempo grafana/tempo \
  --namespace monitoring
```

Now configure Grafana to use Loki and Tempo as data sources. In your Grafana UI, add:

```yaml
apiVersion: 1
datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
  - name: Tempo
    type: tempo
    access: proxy
    url: http://tempo:3100
```

With this setup, you can jump from a metric spike in Prometheus to related logs in Loki and traces in Tempo. This is when monitoring starts becoming observability.

OpenTelemetry introduces a vendor-neutral way to capture metrics, logs, and traces in a single pipeline. Instead of bolting together siloed tools, you get a unified foundation. I'll cover this in detail in the [next post on OpenTelemetry in Kubernetes](/posts/opentelemetry-kubernetes-centralized-observability).

## Conclusion

Kubernetes observability is more than Prometheus and Grafana dashboards. Kube-prometheus-stack gives you a strong monitoring foundation, but it leaves critical gaps in logs, traces, and correlation. If you only rely on it, you will face cardinality explosions, alert fatigue, and dashboards that tell you what went wrong but not why.

True Kubernetes observability requires a mindset shift. You're not just collecting metrics anymore. You're building a system that helps you ask questions you didn't know you'd need to answer. When an incident happens at 3 AM, you want to trace a slow API call from the user request, through your microservices, down to the database query that's timing out. Prometheus alone won't get you there.

To build true Kubernetes observability:

* Accept kube-prometheus-stack as monitoring, not observability
* Add logs and traces into your pipeline
* Watch out for metric cardinality and alert noise
* Move toward OpenTelemetry pipelines for a unified solution

The monitoring foundation you build today shapes how quickly you can respond to incidents tomorrow. Start with kube-prometheus-stack, acknowledge its limits, and plan your path toward full observability. Your future self (and your on-call team) will thank you.

In the next part of this series, I will show how to deploy OpenTelemetry in Kubernetes for centralized observability. That is where the real transformation begins.

**Read next**: [OpenTelemetry in Kubernetes for centralized observability](/posts/opentelemetry-kubernetes-pipeline).