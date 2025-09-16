+++
title = "Elastic Kubernetes Service Cost Optimization: A Comprehensive Guide - Part Two"
description = "Cost optimization is a crucial aspect of Kubernetes management. This blog series explores strategies for reducing expenses on both Kubernetes and AWS sides, starting with universally applicable Kubernetes tips."
date = "2024-05-21"
author = "Fatih Koç"
tags = ["EKS", "AWS", "Cost Optimization", "Spot Instances", "Fargate"]
+++

## Introduction: Deep Diving into AWS EKS Cost Optimization

When companies or projects try to choose the right distribution for Kubernetes, they know most have similar features. High availability, resilience, support, addons for storage, security, etc. It comes to the single most important thing when making a decision. **Cost.**

In the [first part](https://fatihkoc.net/posts/eks-cost-optimization-1/) of this series, we discussed general Kubernetes cost optimization strategies. Now, further delve into Amazon Web Services (AWS) specific strategies to optimize your Elastic Kubernetes Service (EKS) costs. This part focuses on leveraging AWS services, understanding pricing models, and implementing AWS-specific features for cost-effective EKS management.

## Understanding the AWS EKS Pricing Model

AWS charges for EKS based on the control plane usage and EC2 instances or Fargate for worker nodes. Familiarize yourself with the pricing details, including per-hour charges for the EKS control plane and costs associated with EC2 instances or Fargate usage. Keep an eye on price changes and consider reserved instances or savings plans for predictable workloads. Using the [AWS Pricing Calculator](https://calculator.aws/) is essential for price prediction. Try to use Spot & All upfront paid Reserved instances as much as possible.

For predictable workloads, consider purchasing Reserved Instances or Savings Plans. These options provide significant discounts compared to on-demand pricing in exchange for a commitment to a certain level of usage.

![AWS Cost Calculator for EC2](/images/eks-cost-opt-2/aws-cost-calculator-for-ec2.png)


## Optimizing EC2 Instances for Worker Nodes

Choose the right EC2 instance types based on your application’s needs. Utilize Spot Instances for non-critical or flexible workloads to save up to 90% compared to on-demand prices. Use Auto Scaling Groups (ASGs) to dynamically adjust capacity, ensuring you pay only for what you need.

Node auto-scaling is really essential for Kubernetes workloads. Especially in cloud environments where pay-as-you-use models are used, dynamically increasing and decreasing node sizes are crucial. [Cluster-autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler) is a de facto tool for this job. However, this tool is designed for multiple cloud and bare metal environments, so it does not focus on AWS workloads. Slow starts, nongraceful shutdowns, and various problems with APIs are creating a need for an AWS-focused auto-scaling tool.

Karpenter is only focusing on AWS workloads. You can create new instances and run pods on them within seconds. Create templates for capacity types(spot, on-demand), zone, architecture, instance category, type, etc. Check out the [documentation](https://karpenter.sh/) for more details. When a pod can not find enough resources to run, Karpenter immediately creates a new node, and the pod can run within seconds. Also whenever you have more nodes than you need, Karpenter can delete nodes for you. Don’t forget to install an [aws-node-termination-handler](https://github.com/aws/aws-node-termination-handler) for graceful shutdown. Karpenter is also focusing on cost optimization. If you can replace an on-demand node for a spot node, then Karpenter will [replace](https://aws.amazon.com/blogs/containers/optimizing-your-kubernetes-compute-costs-with-karpenter-consolidation/) them. Or it can change its size as well.

I prefer to use [eks-node-viewer](https://github.com/awslabs/eks-node-viewer) to understand node scaling and resource allocations. Karpenter is updating very regularly. They keep adding new features and fixing bugs frequently, so check official documentation before using it and keep it up-to-date.

AWS Fargate allows you to run containers without managing servers or clusters. It’s a great option for workloads with variable resource requirements, as you pay per vCPU and memory used. Fargate can simplify operations and potentially reduce costs for suitable workloads. This one is operation cost vs. compute resource cost. It can be efficient for new projects for head start.

## EKS Networking and its Impact on Costs

Understand and optimize networking components in EKS to control costs. Choose the right VPC and subnet strategies and consider using AWS PrivateLink to reduce data transfer costs. Be mindful of network traffic between availability zones and regions, as these can incur additional charges.

For simple development environments, a single AZ can reduce network costs. EKS control planes run on multi-AZ architecture, but node groups and Fargate instances can run on a single AZ. Also, fewer instance numbers can mean less network communication, reducing costs. Choose instance types and sizes wisely.

Use cache mechanisms as much as possible. The cache can reduce network load and response times. For static workloads, use CloudFront. This can also be useful for web applications. CloudFront + ALB can be used together. Once the user enters the AWS network infrastructure, requests will be faster than before. Caching responses from databases can affect network usage and performance as well. Use it wisely because it might increase resource usage unless properly planned. Don’t forget, cache is king.

If you are using other AWS services like S3, DynamoDB, ECR etc. then use VPC Endpoints. Normally, when you send a request to S3 inside EKS pods, it traverses the internet. AWS charges you for sending the packets to the internet, and it is a less secure and slower way to access a service. VPC endpoints allow you to access some AWS services without traversing the internet. Which is faster, cheaper, and more secure.

NAT Gateways can be really expensive, especially if you have a multi-AZ architecture. There is a trick here. If you use one NAT Gateway for each AZ, you can reduce inter-AZ communication. However, this will increase the price for NAT Gateway usage. You must check whether NAT Gateways or inter-AZ communications are cheaper.

VPC to VPC communication is expensive. You can use public internet, but it comes with a price. Use VPC Peering(2 VPC) and Transit Gateway(+3 VPC) as much as possible. VPC Peering is a great choice for the same AZ because there are no network charges.

![AWS VPC Network](/images/eks-cost-opt-2/aws-vpc-network.png)


## Storage Optimization

Optimize storage costs by choosing the appropriate Elastic Block Store (EBS) or Elastic File System (EFS) for your needs. Use gp2 or gp3 volumes for a balance between performance and cost. Delete unattached volumes and snapshots regularly, and consider lifecycle policies for automated management.

For increased performance for workloads like databases, EC2 instance stores are really powerful choices. Instance store disks can be used with EC2 user-data to format disks. EKS can use them as HostPath persistent volumes. [Local Persistent Volume Static Provisioner](https://github.com/kubernetes-sigs/sig-storage-local-static-provisioner) is also another alternative for local disks. Be careful with them because once you lose your instance, the disks are gone as well. It is useful for high performance for less cost.

Minimize container image sizes and use Amazon Elastic Container Registry (ECR) to store and manage your Docker images. Implement lifecycle policies in ECR to automatically clean up unused images, reducing storage costs.

EKS control plane logs can be disabled for test environments. They can create network workload and storage usage. Storing logs in S3 with the correct tiering mechanism and configuring retention periods are also important.

What about backups? Amazon Data Lifecycle Manager(DLM) can be leveraged to manage automated backups and retention policies. EBS snapshots and AMIs can be controlled with DLM. However, currently DLM is not working via EBS CSI Driver. They can be used seperately. Open-source solutions like [Velero](https://velero.io/) can be used for automated backups and retention policies inside EKS.

## AWS Cost Management Tools

Leverage AWS-native tools like AWS Cost Explorer, Budgets, and Trusted Advisor to monitor and optimize EKS costs. These tools provide insights into your spending patterns, resource utilization, and recommendations for cost savings. Using Cost Explorer with hourly changes can help you understand how your changes affected costs.

Billing and Budget [alerts](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/monitor_estimated_charges_with_cloudwatch.html) must be used on day 1. Otherwise, it will be late once you use more resources than you need. AWS Cost Explorer is updating daily. Hourly price changes can be opt-in. Tagging all of the resources will improve the observability of cost management. With the automation tools like AWS Cloudformation and Terraform, it is much easier. AWS Trusted Advisor is also a must-do operation. Check recommendations and take actions. It will help you to increase usage level of reserved instances and saving plans.

## Security and Compliance on a Budget

Implement security best practices without breaking the bank. Use AWS Identity and Access Management (IAM) roles and policies for granular control over EKS resources. Leverage AWS Certificate Manager for SSL/TLS certificates and AWS Key Management Service (KMS) for encryption, optimizing costs while maintaining security.

## Conclusion

Price optimization can be tricky. You need capacity, faster communication, and highly available workloads, but it is expensive. Try to use this blog post as a guide and figure out your infrastructure needs. Use fewer resources for testing and development environments and don’t think much about high availability, resilience, etc. Production environments are something else so be prepared for what is coming. Use VPC Endpoints and regularly check network costs and what is causing them.

Lastly, AWS Well-Architected Framework helps customers to make decisions about their workloads. Cost Optimization Piller whitepaper can help you with cost reduction. Check out the official [whitepaper](https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/welcome.html). Practice Cloud Financial Management can give you an idea about AWS cost management.

This article is also available on [Medium](https://medium.com/vngrs/elastic-kubernetes-service-cost-optimization-a-comprehensive-guide-part-two-17077e59aede).