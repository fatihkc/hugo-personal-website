+++
title = "From Signals to Reliability: SLOs, Runbooks and Post-Mortems"
description = "Build reliability with SLOs, runbooks and post-mortems. Turn observability into systematic incident response and learning. Practical examples for Kubernetes environments."
date = "2025-11-02"
author = "Fatih Koç"
tags = ["Kubernetes", "SRE", "Observability", "SLO", "DevOps", "Incident Management", "Reliability"]
images = ["/images/sre-observability-slo-runbooks/sre-observability-slo-runbooks.webp"]
featuredImage = "/images/sre-observability-slo-runbooks/sre-observability-slo-runbooks.webp"
+++

> All configuration examples, templates and alert rules are in the [kubernetes-observability](https://github.com/fatihkc/kubernetes-observability) repository.

You can build perfect observability infrastructure. Deploy [unified OpenTelemetry pipelines](/posts/opentelemetry-kubernetes-pipeline/), add [security telemetry](/posts/kubernetes-security-observability/), implement [continuous profiling](/posts/ebpf-parca-observability/). Instrument every service. Collect every metric, log and trace. Build beautiful Grafana dashboards.

And still struggle during incidents.

The missing piece isn't technical. It's organizational. When alerts fire during incidents, your team needs to answer four questions instantly: How severe is this? What actions should we take? Who needs to be involved? When is this resolved?

Without Service Level Objectives, severity becomes subjective. Different engineers will have different opinions about whether a 5% error rate is acceptable or catastrophic. Without runbooks, incident response becomes improvisation. Each engineer follows their own mental model, leading to inconsistent outcomes. Without structured post-mortems, teams fix symptoms but miss root causes, hitting the same issues repeatedly.

The gap between observability and reliability isn't about collecting more data. It's about giving teams the frameworks to act on that data systematically. SLOs define shared understanding of what "working" means. Runbooks codify collective knowledge about remediation. Post-mortems create organizational learning from failures.

This post focuses on the human systems that turn observability into reliability. You'll see how to define SLOs that drive decisions, build runbooks that scale team knowledge, structure post-mortems that generate improvements and embed these practices into engineering culture without adding bureaucracy.

## Why observability alone doesn't prevent incidents

The [OpenTelemetry pipeline post](/posts/opentelemetry-kubernetes-pipeline/) showed how to unify metrics, logs and traces. The [security observability post](/posts/kubernetes-security-observability/) added audit logs and runtime detection. The [profiling post](/posts/ebpf-parca-observability/) covered performance optimization. You have visibility into everything.

But visibility doesn't equal reliability.

Consider a payment service processing transactions. Your observability stack shows:
- Request rate: 1,200 req/sec
- Error rate: 2.3%
- P99 latency: 450ms
- CPU: 65%
- Active database connections: 180

Is this good or bad? Without defined objectives, you're guessing. Some teams would panic at 2.3% errors. Others wouldn't wake up an engineer until it hit 15%. The decision becomes political instead of systematic.

Even worse, when alerts fire, engineers are left improvising. The alert says "high latency" but doesn't tell you whether to restart pods, scale horizontally, check the database, or roll back the last deployment. Every incident becomes a research project.

And without structured retrospectives, you fix the immediate problem but miss the systemic causes. The database connection pool was too small. Configuration changes don't require approval. Deployment rollbacks aren't automated. You'll hit similar issues repeatedly because you're not learning.

SLOs, runbooks and post-mortems solve these problems. They transform observability from passive data collection into active reliability improvement. I've watched teams cut their mean time to resolution by 60% within three months of implementing these practices, not because they collected more data but because they knew how to act on it.

## Service Level Indicators define what actually matters

Service Level Indicators are the specific metrics that measure user-facing reliability. Not internal metrics like CPU or memory. Not infrastructure metrics like pod count. User-facing behavior that customers actually experience.

The four golden signals provide a starting framework: latency (how fast), traffic (how much demand), errors (how many failures) and saturation (how full your critical resources are—CPU, memory, thread/connection pools, queue depth, disk/network I/O). These apply to almost any service, but you need to make them concrete for your specific workload.

For a REST API, your SLIs might be:
- **Availability**: Percentage of requests that return 2xx or 3xx status codes
- **Latency**: 99th percentile response time for successful requests
- **Throughput**: Requests per second the service can handle

For a data pipeline, your SLIs are different:
- **Freshness**: Time between data generation and availability in the warehouse
- **Correctness**: Percentage of records processed without data quality errors
- **Completeness**: Percentage of expected source records present in output

The key is measuring what users experience, not what infrastructure does. Users don't care if your pods are using 80% CPU. They care whether their checkout succeeded and how long it took.

Implement availability SLI using data from your OpenTelemetry pipeline. If you set `namespace: traces.spanmetrics` as above, the span-metrics will be available as `traces_spanmetrics_*` in Prometheus. If you use a different namespace, adjust the metric names accordingly. Example query:

```promql
# Availability SLI: percentage of successful requests
sum(rate(traces_spanmetrics_calls_total{
  service_name="checkout-service",
  status_code=~"2..|3.."
}[5m]))
/
sum(rate(traces_spanmetrics_calls_total{
  service_name="checkout-service"
}[5m]))
```

For latency, use histogram quantiles from your instrumented request duration metrics. With `namespace: traces.spanmetrics`, the duration histogram is exposed as `traces_spanmetrics_duration_bucket` with accompanying `_sum` and `_count`:

```promql
# Latency SLI: 99th percentile response time
histogram_quantile(
  0.99,
  sum by (le) (
    rate(traces_spanmetrics_duration_bucket{
      service_name="checkout-service",
      status_code=~"2.."
    }[5m])
  )
)
```

The OpenTelemetry Collector's spanmetrics connector automatically generates these metrics from traces (older releases exposed this as a processor). You instrument once, get both detailed traces for debugging and aggregated metrics for SLOs. Metric names depend on the connector `namespace` you set, and dots are converted to underscores in Prometheus (e.g., `traces.spanmetrics` → `traces_spanmetrics`).

Example configuration aligning metric names used below:

```yaml
connectors:
  spanmetrics:
    namespace: traces.spanmetrics

service:
  pipelines:
    traces:
      receivers: [otlp]
      exporters: [spanmetrics]
    metrics:
      receivers: [spanmetrics]
      exporters: [prometheusremotewrite]
```

Don't try to create SLIs for everything. Start with 2-3 indicators for your most critical user journeys. For an e-commerce platform, that's probably browse products, add to cart and complete checkout. Each journey gets availability and latency SLIs. That's six total. Manageable.

Avoid vanity metrics disguised as SLIs. "Average response time" is a terrible SLI because it hides outliers. One request taking 30 seconds while 99 others take 100ms averages to 400ms, which looks fine but represents a terrible user experience. Use percentiles instead. P50, P95, P99.

Also avoid internal metrics that don't map to user experience. "Kafka consumer lag" isn't an SLI unless you can translate it into user impact. If lag means users see stale data, then "data freshness" is your SLI. Measure the user-facing symptom, not the internal cause.

## Service Level Objectives turn metrics into reliability targets

SLOs are the targets you set for your SLIs. "99.9% of requests will succeed" or "99% of requests will complete in under 500ms." These targets become the contract between your service and its users.

The right SLO balances user expectations with engineering cost. Setting a 99.99% availability target sounds great until you realize it allows only 4.38 minutes of downtime per month. Achieving that requires redundancy, automation and operational overhead that might not be worth it for an internal tool.

The process for setting SLOs is:
1. Measure current performance for 2-4 weeks
2. Identify what users actually need (talk to them)
3. Set objectives slightly better than current but achievable
4. Iterate based on error budget consumption

Example approach for setting SLOs:

If current performance shows 99.7% availability and P99 latency of 800ms, but user research indicates that occasional slowness is acceptable while failures are not, you might set:
- **Availability**: 99.5% of requests succeed (more conservative than current, providing error budget)
- **Latency**: 99% of requests complete in under 1000ms

These SLOs translate to quantifiable budgets:
- 0.5% error budget = 14.4 hours of downtime per month
- 1% of requests can exceed latency target

This creates clear decision guardrails. When burning error budget faster than expected, teams slow feature releases and focus on reliability. With remaining error budget, teams can take calculated risks on innovation.

Implement SLOs as Prometheus recording rules. This pre-computes the SLI values and makes dashboards faster. The latency example below assumes spanmetrics duration unit is milliseconds and a 1s threshold (le="1000"):

```yaml
groups:
- name: checkout-service-slo
  interval: 30s
  rules:
  # Availability SLI
  - record: sli:availability:ratio_rate5m
    expr: |
      sum(rate(traces_spanmetrics_calls_total{
        service_name="checkout-service",
        status_code=~"2..|3.."
      }[5m]))
      /
      sum(rate(traces_spanmetrics_calls_total{
        service_name="checkout-service"
      }[5m]))
  
  # Latency SLI (percentage of requests under threshold)
  - record: sli:latency:ratio_rate5m
    expr: |
      sum(rate(traces_spanmetrics_duration_bucket{
        service_name="checkout-service",
        le="1000"
      }[5m]))
      /
      sum(rate(traces_spanmetrics_duration_count{
        service_name="checkout-service"
      }[5m]))
```

Then create a Grafana dashboard that shows SLO compliance over time. Add a gauge showing current error budget remaining. When error budget drops below 20%, make it red. This gives teams a visual indicator of risk.

## Error budgets as reliability currency

Error budgets flip the reliability conversation. Instead of "we need 100% uptime" (impossible), you get "we have a budget for failures, spend it on innovation instead of panic."

If your SLO is 99.5% availability over 30 days, your error budget is 0.5% of requests. At 1M requests per day, that's 5,000 failed requests per day or 150,000 per month. Every actual failure reduces your remaining budget.

Calculate error budget burn rate to catch problems before you exhaust your budget:

```promql
# Current error rate vs error budget rate
# If this exceeds 1.0, you're burning budget faster than planned
(1 - sli:availability:ratio_rate5m) / (1 - 0.995)
```

A burn rate of 1.0 means you're consuming error budget at exactly the rate your SLO allows. A burn rate of 10 means you'll exhaust your monthly budget in 3 days at current failure rates. A burn rate of 0.5 means you have headroom.

Multi-window, multi-burn-rate alerting prevents both false positives and slow detection. The Google SRE workbook recommends alerting on two conditions:
1. Fast burn (2% budget consumed in 1 hour) means page immediately
2. Slow burn (5% budget consumed in 6 hours) means ticket for investigation

Here's the alert rule:

```yaml
groups:
- name: checkout-service-slo-alerts
  rules:
  # Fast burn: 14.4x burn rate over 1 hour AND 2 minutes
  - alert: CheckoutServiceErrorBudgetFastBurn
    expr: |
      (1 - sli:availability:ratio_rate5m{service_name="checkout-service"}) / (1 - 0.995) > 14.4
      and
      (1 - sli:availability:ratio_rate5m{service_name="checkout-service"}) / (1 - 0.995) > 14.4 offset 2m
    for: 2m
    labels:
      severity: critical
      team: payments
    annotations:
      summary: "Checkout service burning error budget at 14.4x rate"
      description: "At current error rate, monthly error budget will be exhausted in {{ $value | humanizeDuration }}. Current availability: {{ $labels.availability }}%"
      runbook_url: "https://runbooks.internal/payments/checkout-error-budget-burn"
  
  # Slow burn: 6x burn rate over 6 hours
  - alert: CheckoutServiceErrorBudgetSlowBurn
    expr: |
      (1 - avg_over_time(sli:availability:ratio_rate5m{service_name="checkout-service"}[6h])) / (1 - 0.995) > 6
    for: 15m
    labels:
      severity: warning
      team: payments
    annotations:
      summary: "Checkout service burning error budget at 6x rate"
      description: "Error budget consumption is elevated. Review recent changes."
      runbook_url: "https://runbooks.internal/payments/checkout-error-budget-burn"
```

These thresholds balance false positives against detection time. Fast burn alerts catch severe outages immediately. Slow burn alerts catch gradual degradation before it exhausts your budget.

Error budgets also drive policy decisions. Many teams implement:
- **Green** (>75% budget remaining): Ship features freely, take risks
- **Yellow** (25-75% remaining): Review change requests, prefer low-risk improvements
- **Red** (<25% remaining): Feature freeze, focus on reliability

This policy is enforced through engineering process, not tooling. When your dashboard shows 18% error budget remaining, the team lead knows to defer that risky refactor until next month. I've seen this framework completely change the product-engineering dynamic. Instead of arguing about whether a release is "too risky," teams look at the error budget dashboard and make data-driven decisions in under five minutes.

Error budgets tell you when to act. Runbooks tell you how to act.

## Runbooks transform alerts into action

Runbooks transform alerts from "something is broken" into "here's exactly what to do." Every alert should link to a runbook. No exceptions.

The runbook structure should be consistent across all services:

### Runbook Template

```markdown
# [Service Name] - [Alert Name]

## Summary
One-sentence description of what this alert means and user-facing impact.

## Severity
Critical / Warning / Info

## Diagnosis
1. Check current SLO status: [Grafana dashboard link]
2. Review recent traces: {service_name="checkout-service", status="error"}
3. Correlate with deployments: [ArgoCD/Flux dashboard link]
4. Review metrics: [Grafana dashboard link]

## Mitigation
1. Rollback: `kubectl rollout undo deployment/checkout-service -n production`
2. Scale up: `kubectl scale deployment/checkout-service --replicas=10 -n production`
3. Disable feature: `kubectl set env deployment/checkout-service FEATURE_X=false`

## Escalation
- On-call engineer (15 min) → Service owner → Incident commander → Executive
- Contact: [PagerDuty link]

## Investigation
After mitigation: Check traces, [profiling data](/posts/ebpf-parca-observability/), [audit logs](/posts/kubernetes-security-observability/) and database logs.
```

This template connects directly to your observability stack. The diagnosis section uses the [unified OpenTelemetry pipeline](/posts/opentelemetry-kubernetes-pipeline/) to correlate signals. The investigation section references [profiling](/posts/ebpf-parca-observability/) and [security observability](/posts/kubernetes-security-observability/) when needed.

Runbooks live in Git alongside your service code. Treat them as code: version controlled, peer reviewed, tested. When you deploy a new feature, update the runbook. When an incident reveals a gap, file a PR to improve it.

### Connecting runbooks to alerts

Remember the `runbook.url` annotation we added to the OpenTelemetry pipeline? Now it pays off. Your alerts automatically include runbook links:

```yaml
annotations:
  summary: "{{ $labels.service_name }} error rate above threshold"
  description: "Current error rate: {{ $value }}%. SLO allows 0.5%."
  runbook_url: '{{ $labels.runbook_url }}'
  dashboard: 'https://grafana.internal/d/service-overview?var-service={{ $labels.service_name }}'
  traces: 'https://grafana.internal/explore?queries=[{"datasource":"tempo","query":"{{ $labels.service_name }}","queryType":"traceql"}]'
```

When the PagerDuty notification arrives, it contains:
- What's broken (service name, error rate)
- Current vs expected (SLO threshold)
- Where to look (dashboard link, trace query)
- What to do (runbook link)

The on-call engineer clicks the runbook link and follows the steps. No guessing. No Slack archaeology trying to remember what worked last time.

## Post-mortems drive learning from failures

Post-mortems (also called incident retrospectives or after-action reviews) turn incidents into systemic improvements. The goal isn't to blame individuals. It's to identify process, tooling, or architecture gaps that let the incident happen.

The key principle is **blameless culture**. You assume people made reasonable decisions given the information available at the time. If someone deployed broken code, the question isn't "why did they do that?" It's "why didn't our testing catch it?" and "why could they deploy to production without review?"

### Post-Mortem Template

```markdown
# Incident: [Brief description]

**Date**: [Date] | **Duration**: [Duration] | **Severity**: [Critical/High/Medium]  
**Commander**: [Name] | **Responders**: [Names]

## Impact
- Users affected: [Number/Percentage]
- Revenue impact: [Amount if applicable]
- SLO impact: [Error budget consumed]

## Timeline
Key events: Alert fired → Investigation began → Discovery → Mitigation → Recovery → Resolution

## Root Cause
What changed, why it caused the problem, why safeguards didn't prevent it.

## What Went Well / Poorly
**Well**: Fast detection, effective collaboration, good tooling use  
**Poorly**: Missing alerts, unclear ownership, inadequate testing, manual processes

## Action Items
| Action | Owner | Priority | Due Date | Status |
|--------|-------|----------|----------|--------|
| [Specific improvement] | [Team] | P0-P2 | [Date] | [Status] |

**P0**: Prevents similar incidents | **P1**: Improves detection/mitigation | **P2**: Nice to have

## Lessons Learned
System-level insights, team practice changes, observability gaps identified.
```

Post-mortems happen within 48 hours of incident resolution while details are fresh. Schedule a 60-minute meeting with all responders plus relevant stakeholders. Use the template to guide discussion.

The action items section is critical. These must have owners, due dates and tracking. Follow up in sprint planning to ensure they're prioritized. Otherwise post-mortems become theater where everyone nods, writes "we should monitor better" and changes nothing.

### Common Post-Mortem Anti-Patterns

**Blame disguised as process**: "Should have known better" is wrong (ask why the system allowed it). 
**Vague action items**: "Improve monitoring" is useless (be specific with dates and metrics). 
**No follow-through**: Make action items sprint backlog priorities. 
**Learning in silos**: Share post-mortems across engineering. 
**Incident theater**: If you're not implementing action items, stop writing post-mortems (you're wasting time).

A common anti-pattern: teams mark post-mortem action items "complete" yet only patch immediate symptoms, leaving systemic fixes undone. That's not learning. That's paperwork.

### External resources and real incident reports

Strengthen SEO and give readers practical references with these authoritative links:

- **Google SRE Workbook**: guidance on blameless post-mortems and error budgets — [sre.google/workbook](https://sre.google/workbook/)
- **Atlassian Incident Management**: incident handbook and templates — [atlassian.com/incident-management](https://www.atlassian.com/incident-management)
- **PagerDuty Incident Response Guide**: practical postmortem guidance — [response.pagerduty.com](https://response.pagerduty.com/)
- **GitLab incidents (public)**: searchable incident issues and retrospectives — [gitlab.com/gitlab-com/gl-infra/production/-/issues?label_name[]=incident](https://gitlab.com/gitlab-com/gl-infra/production/-/issues?label_name%5B%5D=incident)
- **Cloudflare incidents**: engineering blog write-ups — [blog.cloudflare.com/tag/outage](https://blog.cloudflare.com/tag/outage/)
- **GitHub engineering**: reliability and incident engineering posts — [github.blog/engineering](https://github.blog/engineering/)
- **GCP incident history**: cloud provider public incident reports — [status.cloud.google.com](https://status.cloud.google.com/)
- **Azure status history**: historical incidents — [azure.status.microsoft/en-us/status/history](https://azure.status.microsoft/en-us/status/history/)
- **Postmortem Library (ilert)**: curated real-world incidents — [ilert.com/postmortems](https://www.ilert.com/postmortems)

How to find other companies' incident reports:
- Search engineering blogs for tags like "incident", "postmortem", or "outage" (e.g., `site:company.com/engineering incident`).
- Check public status pages for "history" or "post-incident" sections.
- Look in product/infra repos for labels like `incident`, `postmortem`, or `root-cause`.

## Building a reliability culture that sticks

SLOs, runbooks and post-mortems fail when they're mandated top-down without team buy-in. You need to embed these practices into daily work, not layer them on as bureaucracy.

### Adoption strategy

Pick your most critical user journey. Define 2-3 SLIs, set SLOs, build the dashboard. When the next incident hits, the team will see immediate value (clear error budget impact, guided response via runbook, concrete improvements from post-mortem). Success with one service creates organic demand. Teams resist until they watch another team resolve an incident in 15 minutes with clear runbooks and error budget data.

Don't create a central "reliability team" that owns all SLOs and runbooks (it doesn't scale). Provide templates (Prometheus recording rules, Grafana dashboards, runbook and post-mortem templates) and let service teams customize for their needs. Payments cares about transaction success rate, search cares about result freshness. Same framework, different metrics.

### Tie it to incentives

What gets measured gets managed. If your promotion criteria include "delivered 5 features" but not "maintained 99.9% SLO," engineers will optimize for features.

Include reliability metrics in team goals:
- Maintain SLO compliance (>95% of time periods meet target)
- Zero incidents without runbooks
- All critical incidents get post-mortems within 48 hours
- Action items from post-mortems completed within 30 days

Celebrate reliability wins like you celebrate feature launches. When a team goes three months without exhausting error budget, that's worth recognition.

### Integrate with existing workflows

Embed reliability into existing processes. 

**Sprint planning**: Review error budget consumption. 
**Stand-ups**: Report SLO status alongside feature progress. 
**Code reviews**: Check for instrumentation and runbook updates. 
**Retrospectives**: Use post-mortem template for incidents that impacted SLOs.

Assign one engineer per team as "observability champion," the point person for defining SLIs/SLOs, keeping runbooks updated, facilitating post-mortems and sharing practices. Champions meet monthly to share patterns and standardize tooling.

### Psychological safety as foundation

None of this works without psychological safety. Blameless culture means focusing accountability on systems and processes, not individuals. When broken code deploys, ask "Why didn't our CI catch this?" not "Why didn't you test properly?" When someone makes a poor architectural decision, ask "What information would have helped?" Leaders set the tone: "what can we learn?" not "who screwed up?"

## Bringing it all together

Observability without reliability practices is data for data's sake. Reliability practices without observability are guesswork. Together, they transform reactive firefighting into proactive reliability engineering.

These practices create organizational capabilities beyond tooling. **Shared understanding** of reliability (SLO compliance, error budgets), **collective knowledge** about remediation (runbooks that scale), **correlated signals** from unified observability (metrics, logs and traces) and **systematic learning** from failures (post-mortems that drive improvement).

Start small. One service, two SLIs, three runbooks. Prove value, then scale. The 60% MTTR improvements, the 5-minute risk decisions, the prevention of repeat incidents aren't aspirational. They're achievable within months of adopting these practices. The infrastructure is ready. Now turn signals into reliability through human systems and team practices.