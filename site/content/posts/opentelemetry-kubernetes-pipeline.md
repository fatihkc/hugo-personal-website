+++
title = "Building a Unified OpenTelemetry Pipeline in Kubernetes"
description = "Deploy OpenTelemetry Collector in Kubernetes to unify metrics, logs, and traces with correlation, smart sampling, and insights for faster incident resolution."
date = "2025-10-12"
author = "Fatih Koç"
tags = ["Kubernetes", "OpenTelemetry", "Observability", "SRE"]
images = ["/images/opentelemetry-kubernetes-pipeline/opentelemetry-kubernetes-observability.webp"]
featuredImage = "/images/opentelemetry-kubernetes-pipeline/opentelemetry-kubernetes-observability.webp"
+++

> All configurations, instrumentation examples, and testing scripts are in the [kubernetes-observability](https://github.com/fatihkc/kubernetes-observability) repository.

Last year during a production incident, I debugged a payment failure with all the standard tools open. Grafana showed CPU spikes. CloudWatch had logs scattered across three services. Jaeger displayed 50 similar-looking traces. Twenty minutes in, I still couldn't answer the basic question: "Which trace is the actual failing request?" The alert told us payments were broken. The logs showed errors. The traces existed. But nothing connected them. I ended up searching request IDs across log groups until I found the culprit.

The problem wasn't tools or data. We had plenty of both. The problem was correlation, or the complete lack of it.

In the [first post about kube-prometheus-stack](/posts/monitoring-kube-prometheus-stack/), I showed why monitoring dashboards aren't observability. This post shows you how to actually build observability with OpenTelemetry. You'll get metrics, logs, and traces flowing through a unified pipeline with shared context that lets you jump from an alert to the exact failing trace in seconds, not hours.

## OpenTelemetry solved vendor lock-in (and a bunch of other problems)

OpenTelemetry is a [CNCF graduated project](https://www.cncf.io/projects/opentelemetry/) that gives you vendor-neutral instrumentation libraries and a Collector that receives, processes, and exports telemetry at scale. Instead of coupling your application code to specific vendors, you instrument once with OTel SDKs and route telemetry wherever you need.

In a freelance project, I migrated from kube-prometheus-stack to OTel. We needed custom metrics, logs, and traces. But vendor lock-in was the real concern. Kube-prometheus-stack worked for basic Prometheus metrics, but adding distributed tracing meant bolting on separate systems. And vendors get expensive fast.

With OTel, I instrumented applications once and kept the flexibility to evaluate backends without touching code. We started with self-hosted Grafana, then tested a commercial vendor for two weeks by changing just the Collector's exporter config. Zero application changes. That flexibility is the win.

But vendor flexibility isn't even the main benefit. The real value is centralized enrichment and correlation. Every signal that passes through the Collector gets the same Kubernetes metadata (pod, namespace, team annotations), the same sampling decisions, and the same trace context. This means your logs have the same `service.name` and `trace_id` as your traces, which have the same attributes as your metrics.

When everything shares context, you can finally navigate between signals during an incident instead of manually correlating timestamps and guessing.

## Three ways to deploy the Collector

Most teams deploy collectors wrong. They either sidecar everything and watch YAML explode, or they DaemonSet everything and wonder why nodes run out of memory.

You can run OTel Collectors as sidecars, DaemonSets, or centralized gateways. Each pattern has trade-offs:

| **Pattern** | **Description** | **Pros** | **Cons** | **Best for** |
|------------|----------------|---------|---------|-------------|
| **Sidecar** | One Collector container per pod | Strong isolation, per-service control, lowest latency | More YAML per workload, harder to scale config | High-security workloads or latency-sensitive apps |
| **DaemonSet (Agent)** | One Collector per node | Simple ops, collects host + pod telemetry, fewer manifests | Limited CPU/memory for heavy processing | Broad cluster coverage with light transforms |
| **Gateway (Deployment)** | Centralized Collector service | Centralized config, heavy processing, easy fan-out | Extra network hop, potential bottleneck | Central policy, sampling, multi-backend routing |

I use DaemonSet agents on each node for collection plus a gateway Deployment for processing. The agent forwards raw signals to the gateway, which applies enrichment, sampling, and routing.

This keeps node resources light and centralizes the complex configuration in one place. I've seen teams try to do heavy processing in DaemonSet agents and then wonder why their nodes run out of memory. Don't do that.

## Installing the OpenTelemetry Operator in Kubernetes

You can deploy Collectors with raw manifests, but the [OpenTelemetry Operator](https://opentelemetry.io/docs/kubernetes/operator/) gives you a `OpenTelemetryCollector` CRD that handles service discovery and RBAC automatically. The Operator needs cert-manager for its admission webhooks:

```bash
# Install cert-manager first
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.yaml
```

Wait about a minute for cert-manager to be ready. Then install the Operator:

```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

helm install opentelemetry-operator open-telemetry/opentelemetry-operator \
  --namespace opentelemetry-operator \
  --create-namespace \
  --set manager.replicas=2

kubectl -n opentelemetry-operator get pods
```

The `manager.replicas=2` ensures high availability. Once installed, you define Collectors as custom resources and the Operator provisions everything else.

### Alternative: install via opentelemetry-kube-stack Helm chart

If you prefer a single Helm chart that bundles common components, you can use the `opentelemetry-kube-stack` chart. It provides a quicker bootstrap for cluster-wide telemetry and is a good starting point before you split configs into dedicated Operator-managed Collectors for more control.

```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
helm install otel-kube-stack open-telemetry/opentelemetry-kube-stack \
  --namespace observability \
  --create-namespace
```

See the chart for options and structure: [opentelemetry-kube-stack](https://github.com/open-telemetry/opentelemetry-helm-charts/tree/main/charts/opentelemetry-kube-stack)

## OpenTelemetry Gateway Collector configuration

The gateway receives OTLP (OpenTelemetry Protocol) signals, the standard wire protocol that carries metrics, logs, and traces over gRPC (port 4317) or HTTP (port 4318). It enriches them with Kubernetes metadata, applies intelligent sampling, and exports to backends. Here's the key piece, the k8sattributes processor:

```yaml
processors:
  k8sattributes:
    auth_type: serviceAccount
    extract:
      metadata: [k8s.namespace.name, k8s.pod.name, k8s.deployment.name]
      annotations:
        - tag_name: team
          key: team
          from: pod
        - tag_name: runbook.url
          key: runbook-url
          from: pod
```

This automatically adds Kubernetes metadata to every signal. The annotations block extracts custom pod annotations like `team` and `runbook-url`, so every trace, metric, and log includes ownership and a link to remediation steps. During an incident, this saves you from hunting through wikis or Slack to figure out who owns the failing service.

For sampling, I use tail-based sampling that keeps 100% of errors and slow requests. If your app processes 10 million requests per day and you store every trace, you'll burn through storage and query performance. 

Sampling keeps a percentage of traces while discarding the rest. The problem with basic probabilistic sampling is it treats all traces equally. You might sample 10% of everything and miss critical error traces. 

Tail-based sampling is smarter. It waits until the trace completes, then decides based on rules:

```yaml
  tail_sampling:
    decision_wait: 10s
    policies:
      - name: errors-first
        type: status_code
        status_code: {status_codes: [ERROR]}
      - name: slow-requests
        type: latency
        latency: {threshold_ms: 2000}
      - name: probabilistic-sample
        type: probabilistic
        probabilistic: {sampling_percentage: 10}
```

This keeps 100% of errors, 100% of requests over 2 seconds, and 10% of everything else. You get full visibility into problems while reducing storage by 80-90%. Start conservative at 10% and increase sampling for high-value flows as you understand query patterns.

The memory_limiter processor prevents OOM kills by back-pressuring receivers when memory usage approaches limits:

```yaml
  memory_limiter:
    check_interval: 1s
    limit_mib: 3072
    spike_limit_mib: 800
```

The complete gateway configuration with all receivers, exporters, and resource limits is in [gateway.yaml](https://github.com/fatihkc/kubernetes-observability/blob/main/opentelemetry/basic-pipeline/gateway.yaml). Deploy it:

```bash
kubectl create namespace observability
kubectl apply -f gateway.yaml
kubectl -n observability get pods -l app.kubernetes.io/name=otel-gateway
```

If you export metrics to Prometheus via the `prometheusremotewrite` exporter, ensure Prometheus is started with `--web.enable-remote-write-receiver`. 

Alternatives: target a backend that supports remote write ingestion natively (e.g., Grafana Mimir, Cortex, Thanos), or use the Collector's `prometheus` exporter and configure Prometheus to scrape it instead.

## DaemonSet agent configuration

The agent config is minimal. Just receive, batch, and forward:

```yaml
spec:
  mode: daemonset
  config: |
    receivers:
      otlp:
        protocols: {http: {endpoint: 0.0.0.0:4318}, grpc: {endpoint: 0.0.0.0:4317}}
      hostmetrics:
        scrapers: [cpu, memory, disk, network]
    
    processors:
      batch: {timeout: 5s}
      memory_limiter:
        check_interval: 1s
        limit_mib: 400
        spike_limit_mib: 100
    
    exporters:
      otlp:
        endpoint: otel-gateway.observability.svc.cluster.local:4317
    
    service:
      pipelines:
        traces: {receivers: [otlp], processors: [memory_limiter, batch], exporters: [otlp]}
        metrics: {receivers: [otlp, hostmetrics], processors: [memory_limiter, batch], exporters: [otlp]}
        logs: {receivers: [otlp], processors: [memory_limiter, batch], exporters: [otlp]}
```

The agent collects host metrics plus OTLP signals from pods, batches them, and forwards to the gateway. Keep processing minimal to preserve node resources. Full configuration in [agent.yaml](https://github.com/fatihkc/kubernetes-observability/blob/main/opentelemetry/basic-pipeline/agent.yaml).

```bash
kubectl apply -f agent.yaml
kubectl -n observability get pods -l app.kubernetes.io/name=otel-agent -o wide
```

## Instrumenting applications

Applications must emit signals for collectors to work. Here's a Python Flask app with OpenTelemetry tracing:

```python
from flask import Flask, request
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor

resource = Resource.create({
    "service.name": "checkout-service",
    "service.version": "v1.0.0",
    "deployment.environment": "production",
    "team": "payments",
})

trace_provider = TracerProvider(resource=resource)
otlp_exporter = OTLPSpanExporter(
    endpoint="http://otel-agent.observability.svc.cluster.local:4318/v1/traces"
)
trace_provider.add_span_processor(BatchSpanProcessor(otlp_exporter))
trace.set_tracer_provider(trace_provider)

app = Flask(__name__)
FlaskInstrumentor().instrument_app(app)

@app.route("/checkout", methods=["POST"])
def checkout():
    with trace.get_tracer(__name__).start_as_current_span("checkout") as span:
        span.set_attribute("user.id", request.json.get("user_id"))
        # Business logic here
        return {"status": "success"}, 200
```

Deploy with pod annotations for the Collector to discover:

```yaml
metadata:
  annotations:
    team: "payments"
    runbook-url: "https://runbooks.internal/payments/checkout"
```

Every trace now includes `service.name`, `team`, and `runbook.url`. During incidents, you can filter by team in Grafana and get instant access to remediation docs.

## Correlation is everything

A unified pipeline only matters if you can actually navigate between signals during an incident. You see an alert fire for high error rates. You need the logs for that service. Then you need the exact trace that failed. Without correlation, you're manually matching timestamps across three different tools and hoping you found the right request. With proper correlation, you click through from alert to logs to trace in seconds. This requires three things: consistent resource attributes like `service.name` and `team` across all signals, trace context (`trace_id` and `span_id`) injected into every log line, and data sources configured in Grafana to link between them.

Add trace context to logs with the OTel SDK:

```python
import logging
from flask import Flask, request
from opentelemetry import trace
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.http._log_exporter import OTLPLogExporter

# Reuse the resource defined earlier for tracing
# resource = Resource.create({"service.name": "checkout-service", ...})

log_exporter = OTLPLogExporter(
    endpoint="http://otel-agent.observability.svc.cluster.local:4318/v1/logs"
)
logger_provider = LoggerProvider(resource=resource)
logger_provider.add_log_record_processor(BatchLogRecordProcessor(log_exporter))

handler = LoggingHandler(logger_provider=logger_provider)
logging.getLogger().addHandler(handler)
logging.getLogger().setLevel(logging.INFO)

tracer = trace.get_tracer(__name__)

@app.route("/checkout", methods=["POST"])
def checkout():
    with tracer.start_as_current_span("checkout") as span:
        span_context = trace.get_current_span().get_span_context()
        logging.info("Processing checkout", extra={
            "trace_id": format(span_context.trace_id, "032x"),
            "span_id": format(span_context.span_id, "016x"),
            "user_id": request.json.get("user_id")
        })
        # Business logic here
        return {"status": "success"}, 200
```

With `trace_id` in logs, you build a Grafana dashboard that shows a Prometheus alert for high error rate, Loki logs filtered by `service.name` and `trace_id`, and the Tempo trace showing the full request flow. Click the alert, see logs, jump to trace. Incident resolution drops from hours to minutes.

## Validate before you go to production

Before production, validate each pipeline with a smoke test:

```bash
kubectl -n observability port-forward svc/otel-gateway 4318:4318

curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "resource": {"attributes": [{"key": "service.name", "value": {"stringValue": "test-service"}}]},
      "scopeSpans": [{
        "spans": [{
          "traceId": "5b8aa5a2d2c872e8321cf37308d69df2",
          "spanId": "051581bf3cb55c13",
          "name": "test-span",
          "kind": 1,
          "startTimeUnixNano": "1609459200000000000",
          "endTimeUnixNano": "1609459200500000000"
        }]
      }]
    }]
  }'

kubectl -n monitoring port-forward svc/tempo 3100:3100
curl http://localhost:3100/api/search?q=test-service
```

If traces, metrics, and logs all reach their backends, you're ready. Full validation scripts including metrics, logs, and traces are in [test-pipeline.sh](https://github.com/fatihkc/kubernetes-observability/blob/main/opentelemetry/basic-pipeline/testing/test-pipeline.sh).

## Operations and scaling

Treat OTel Collector config like application code. Store manifests in Git, require PR approval for config changes, deploy to dev then staging then production, and alert on Collector health (queue size, drop rate, CPU/memory).

Enable HPA for the gateway based on CPU:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: otel-gateway
  namespace: observability
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: otel-gateway
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

Monitor Collector-specific metrics exposed on `:8888/metrics` like `otelcol_receiver_accepted_spans`, `otelcol_receiver_refused_spans`, `otelcol_exporter_sent_spans`, `otelcol_exporter_send_failed_spans`, and `otelcol_processor_batch_batch_send_size`. Alert if refused or send_failed metrics spike.

## Grafana cross-navigation

To enable click-through from metrics to logs to traces, configure Grafana data source correlations. In the Tempo data source, add a trace-to-logs link:

```json
{
  "datasourceUid": "loki-uid",
  "tags": [{"key": "service.name", "value": "service_name"}],
  "query": "{service_name=\"${__field.labels.service_name}\"} |~ \"${__span.traceId}\""
}
```

In the Loki data source, add a logs-to-trace link:

```json
{
  "datasourceUid": "tempo-uid",
  "field": "trace_id",
  "url": "/explore?left={\"datasource\":\"tempo-uid\",\"queries\":[{\"query\":\"${__value.raw}\"}]}"
}
```

When you view a trace in Tempo, you can click "Logs for this trace" and see all related log lines. From Loki, you can click a `trace_id` field and jump directly to the trace.

## What we actually got from this migration

In a production migration I led last year, we consolidated three separate agents (Prometheus exporter, Fluentd, Jaeger agent) into a single OTel pipeline. After 3 months:

Incident resolution time dropped from 90 minutes (median) to 25 minutes. Engineers stopped jumping between four tools. One Grafana dashboard with cross-links was enough. Trace sampling reduced storage by 85% with no loss in debug capability. The `team` attribute and `runbook.url` in every signal eliminated "who owns this?" questions.

The biggest win wasn't technical. It was operational.

On-call engineers stopped guessing and started following a clear path: alert, dashboard, trace, runbook. When you can click through from a Prometheus alert to Loki logs to the exact failing trace in Tempo, observability stops being theoretical and starts being useful.

Deploy the gateway and agent, instrument one service, and test cross-navigation in Grafana. Once you see it work, you'll understand why unified pipelines matter. Understanding [Kubernetes deployment patterns](/posts/k8s-deployment-guide/) helps when running monitoring infrastructure reliably, especially when you need to ensure collectors stay running during cluster upgrades.

## Read next

Now that you have a unified observability pipeline for metrics, logs, and traces, extend it to security signals. [Security Observability in Kubernetes Goes Beyond Logs](/posts/kubernetes-security-observability/) shows you how to add Kubernetes audit logs, Falco runtime detection, and network flow visibility to your OpenTelemetry pipeline with full correlation. You'll be able to trace security events back to the exact request that triggered them.