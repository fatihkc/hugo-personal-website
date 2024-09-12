+++
title = "Elastic Kubernetes Service Cost Optimization: A Comprehensive Guide - Part One"
description = "Cost optimization is a crucial aspect of Kubernetes management. This blog series explores strategies for reducing expenses on both Kubernetes and AWS sides, starting with universally applicable Kubernetes tips."
date = "2024-05-07"
aliases = ["eks", "cost-optimization", "kubernetes", "aws", "eks-cost-optimization"]
author = "Fatih Koç"
+++

Elastic Kubernetes Service (EKS) stands out in the Kubernetes ecosystem for its powerful cloud-based solutions. However, many organizations struggle with managing costs effectively. This two-part blog series dives deep into strategies for reducing expenses on both Kubernetes and AWS sides. We start with universally applicable Kubernetes tips, enriched with contextual understanding and real-world scenarios.

## Monitoring and Logging: The First Step in Cost Management

Effective cost management begins with robust monitoring and logging. Start with cloud provider dashboards and virtualization technology interfaces for basic insights. Install metrics-server to leverage commands like `kubectl top pods` and `kubectl top nodes` for real-time data. For comprehensive infrastructure monitoring, consider the [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack), which includes Grafana, Prometheus, node-exporter, Alertmanager, and optionally Thanos.

### Install metrics-server

    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

### Install kube-prometheus-stack

    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack

While some prefer the ELK stack for logging, its resource intensity for simple syslogs is a drawback. A more efficient alternative for pod logs is the combination of Loki and Promtail, seamlessly integrating with Grafana for monitoring and logging and significantly reducing storage requirements.

Enterprise APM solutions like Dynatrace, Datadog, New Relic, Splunk, etc. can be used for monitoring solutions, but since we are discussing cost management, they are not necessary for small clusters.

![kube-prometheus-stack dashboard](/images/eks-cost-opt-1/kube-prometheus-stack-dashboard.png)

## Resource Management: Tuning for Efficiency

Now, we have a monitoring and logging stack. Which pods or nodes are using how many resources can be seen? Node types and sizes that fit our applications can be chosen. If you are new to Kubernetes, you can see some blog posts discussing whether to use requests/limits for containers. Long story short, start with requests. Watch your containers, check average usage, and add %25 more requests for containers average usage. Using limits can create massive chaos in your environment unless you know why you are using it. If your application needs that limit, then use it. If you are not sure about that, don't use limits.

Requests are allocation resources for your containers, so the kube-scheduler can decide which nodes can run your applications while scheduling. Pods are running with guaranteed resources. Limits basically kill your pods when they reach limits, so if you have a problem with your application, they will keep dying. High risk, low reward.

## Horizontal Pod Autoscaler(HPA): Scaling with Demand

HPA is pivotal in cloud environments where payment is based on usage. It automatically adjusts pod numbers in response to resource demand changes. Custom metrics can trigger scaling activities, for which [KEDA](https://keda.sh/) offers a versatile solution. Effective HPA implementation ensures you scale resources efficiently, aligning costs with actual needs.

Pod count is important because it affects your node count as well. Unfortunately, there are limits for container counts. The maximum number of pods can be limited to Container Network Interface plugins, IP address allocations, network interfaces, resource constraints etc.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: php-apache
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```

## Managing Workloads: Strategic Updates and Scaling

Regular updates and pruning of deployments and rolling updates contribute to cost optimization. Cluster auto-scalers, a feature supported differently by various cloud providers, can significantly reduce costs by dynamically adjusting resources. The [Cluster Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler) project is a valuable tool in this regard. The next blog post will cover the specifics of AWS's approach.

For bare metal installations, you don't have too many options. You can use autoscalers for infrastructures like OpenStack. At best, you can reduce resource usage, but license costs will always be the same. For example, if you are using bare metal Openshift, you still pay a license fee for worker machines whether you use them or not.

On the other hand, cloud providers are using the pay-as-you-use concept. Even one less worker node can affect machine, network, disk, and operation costs. Most of the cloud providers offer autoscalers designed for Kubernetes workloads like Karpenter. With the right configuration, the impact can be huge.

## Optimize Images: Balancing Efficiency and Security

We have discussed the infrastructure part; now, we can focus on our applications and images. Minimizing images can provide efficiency, security, speed, and cost reduction. You don't want to pull a 200 GB Ubuntu image when you can do the same job with a 20 MB stretch image, right? This is especially important for security. Fewer binaries and libraries mean a lower attach surface. Besides, storing images can be costly as well. Try to use scratch or alpine images as much as possible.

## Namespace Management and Resource Quotas: Effective Segregation

Segregating different environments like dev, staging, and production within the same cluster can help monitor and set resource quotas. Setting quotas on namespaces to prevent a single team or project from consuming all cluster resources. A development namespace with a set quota to ensure that resource-intensive test workloads don't impact production services.

```yaml

apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-resources
spec:
  hard:
    requests.cpu: "1"
    requests.memory: 1Gi
    limits.cpu: "2"
    limits.memory: 2Gi
    requests.nvidia.com/gpu: 4
```

## Hidden Enemy: Network Costs

Using multiple region availability zones can be good for high availability, but it comes with a price. Be aware of costs between regions, availability zones, and virtual machines. Every provider has a different policy about network costs. Caching strategies can also reduce network traffic and data transfer costs.

Continuous monitoring and making simple improvements daily is the most efficient way to decrease network costs. Use cost calculator applications for cloud providers while deciding on infrastructure.

## Monitoring Cost Optimization: Tools

![eks-node-viewer](/images/eks-cost-opt-1/eks-node-viewer.png)

eWe have discussed most of the tips and tricks about Kubernetes cost management. Still, we want to be sure about everything. Cost monitoring tools like OpenCost and Kubecost can be used. For understanding cluster-wide resource usage, [eks-node-viewer](https://github.com/awslabs/eks-node-viewer) is a really useful tool.

## Part Two

Kubernetes cost optimization can be used for every platform, including cloud and bare-metal infrastructures. In the next chapter(), we will discuss the cost optimization of AWS components. We will focus on leveraging AWS services, understanding pricing models, and implementing AWS-specific features for cost-effective EKS management.

This blog is originally published on [Medium](https://medium.com/vngrs/elastic-kubernetes-service-cost-optimization-a-comprehensive-guide-part-one-ef51b3c64ed5).