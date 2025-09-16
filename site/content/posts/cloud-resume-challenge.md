+++
title = "Cloud Resume Challenge"
description = "End-to-end serverless portfolio website for Cloud Resume Challenge."
date = "2022-08-22"
author = "Fatih Koç"
tags = ["AWS", "Serverless", "Terraform", "Hugo", "CloudFront"]
+++

Hello everyone, I am Fatih. I am working in the cloud area for over two years. Currently working as a DevOps Engineer at FTech Labs, we're building a super app for crypto exchanges. Today our topic is [Cloud Resume Challenge](https://cloudresumechallenge.dev/).  

## Motivation

I had a [website](https://github.com/fatihkc/) built with Django. I've dockerized it and deployed it to the EC2 instance. Turns out it keeps failing with a new error every time. Most of the time docker-compose can not manage to make it available on 7/24. I decided to keep it shut down. I kept thinking about creating a new website in a serverless way but it never happened. Always too busy with something and do not want to waste my time on a simple website.
Then I found out Cloud Resume Challenge. It's giving you the basic steps of a serverless portfolio website for beginners but there are so many people doing it with over +10 years of experience in IT. I thought I can test my skills with a challenge and make a website that doesn't waste my time.

## Cloud Resume Challenge Steps

![Cloud Resume Challenge Steps](/images/cloud-resume-challenge/cloud-resume-challenge-steps.jpg)

You can check the steps on the [website](https://cloudresumechallenge.dev/docs/the-challenge/). They change in time. It seems basic right? You can probably finish it within a month just using your spare time. Also, there are additional steps for making it amazing. You can also check out the book written for this challenge. It is really helpful for getting a cloud job. 

## Technologies

![Diagram](/images/cloud-resume-challenge/diagram.png)

You can check my GitHub [repository](https://github.com/fatihkc) for this challenge. I am not gonna give the details about technical things. You can check the repo and read the comments. I skipped the certification part. I will explain it later.

I knew most of the technical stuff in the challenge, so I decided to use Terraform for giving a little bit of excitement to the challenge. 

- Hugo: I chose Hugo for static website generation because it uses Go and I love it. I have a little repository for my Golang practices. It is easy to use and fast. I could use HTML+CSS for my resume but I wanted to add an image. I like the way it looks and I already knew a few things about HTML, CSS, Javascript, etc.

- AWS: I am using it for my job and It is the leader of the cloud providers. Just don't forget to create an IAM user and billing alerts. You don't want to pay thousands of dollars for a simple website, right? 

- Terraform: I am huge fan of Terraform. In FTech Labs, we are creating, configuring, and scaling with IaC tools. Manual things are banned because they can cause damage and it becomes harder to fix them. Don't forget to create an S3 bucket for states and DynamoDB for state locking. After that, you can create your cloud infrastructure with HCL. 

- GitHub Actions: I used different CI tools but never used GH Actions before. It is fast, easy to configure, and free for public repositories. I am managing my build, deployment, and test steps. Terraform is triggering manually because I don't want to use it every time.

## What did I learn?

I used new tools and turns out I am a fast learner. A few years ago this challenge can take forever. However, the main thing about this challenge is the [book](https://cloudresumechallenge.dev/book/) itself. I learned a few tricks about understanding technologies, documentation reading, and career changes. I also started blogging with this post. I have another blog idea and I am excited about it. 

I figured out my resume had a huge problem. I was generally working alone with infrastructures and used so many different tools, architectures, etc. But I couldn't prove it. GitHub repositories were created years ago, I don't have a certificate, I don't blog about anything, etc. If you want to get a cloud job, your resume must be sexy. If you can't pass the HR resume process, your technical knowledge is not that important. Nobody will ask you about your previous work, test your skills or give assignments. 

## What's next?

That is why I am going to focus on blogging, certificates, and making more repositories about my skills. I passed the certification process in the challenge because I wanted to focus on them later on. The challenge gave me a moral boost and a good project for my resume. Thanks to [Atomic Habits](https://jamesclear.com/atomic-habits), I just start a thing and see how it goes. I am going to keep blogging and create a project for the blog posts. The most important thing is certifications. So many people are arguing about it whether you need to take it or leave. Most of the job posts are not demanding but I talked to a lot of HR people and they say I will give you a boost depending on the certification. Especially in consulting world, you must have a few certificates to improve your company's partnership level.

I got my first job before graduation. Technical interviews were generally easy because when they asked about my GNU/Linux skills, I told them I gave a few lectures in different boot camps. I added them to my resume. I wasn't planning to become an instructor but when people see your resume they will know that you know a few things about basic GNU/Linux administration. Generally, people were skipping GNU/Linux questions. Certificates are the same. When you have them, most people won't even ask about them, and HR people like them very much. If you prepared and learned things about certificate topics during the preparation, interviews will be much easier than before. 

AWS Cloud Practitioner, AWS Solutions Architect - Associate, and Certified Kubernetes Administrator are my main targets for now. Why Cloud Practitioner? I can easily get it without even looking at example questions. My main goal is to learn the process of certification in AWS. It won't be hard and I won't be stressed about it. That way, Solutions Architect - Associate will be easier than before. Also, an additional certificate won't hurt. CKA will be last one and then I will create a new roadmap for my career. 

I hope you enjoyed my first blog post. Let's create another one!
