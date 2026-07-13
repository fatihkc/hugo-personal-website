+++
title = "How I Built an AI System That Codes, Runs and Improves Itself"
description = "I built an AI system that writes its own code, ships it and runs a live site end to end. My only job is reviewing the pull requests it opens."
date = "2026-07-13"
author = "Fatih Koç"
tags = ["AI", "DevOps", "Automation"]
images = ["/images/ai-system-that-improves-itself/ai-system-that-improves-itself.webp"]
featuredImage = "/images/ai-system-that-improves-itself/ai-system-that-improves-itself.webp"
+++

A few weeks ago, during a meeting at my day job, my phone buzzed. My website had picked the topic from trend data days earlier, written the draft, scored it against an editorial rubric and opened a pull request with the finished article, the same way it opens PRs to change its own code. I skimmed it during a coffee break and merged. That merge published the article and pushed it out to social media, and it was my entire involvement in that day's publishing.

The site is [DevOps Start](https://devopsstart.com), a content site I built with AI and then handed back to AI to run. It discovers topics, writes articles, gates their quality, opens a pull request for each finished piece, distributes what I merge, reads its own analytics and proposes improvements to its own pipeline. Its own code changes arrive the same way, as pull requests from nightly routines. My only recurring job is reviewing those PRs over breakfast and merging the ones that pass.

Let me declare this clearly, because the whole point gets lost otherwise. This was never about traffic or revenue. The real project is a self-improving AI system, one that writes its own code, ships it, runs a live site end to end and rewrites its own pipeline when the numbers say it should. DevOps Start is just the simplest thing I could point it at. Building that system was the goal. The site is only where I proved it works.

## It Started With RSS Fatigue

For years my mornings began the same way. Open the RSS reader, stare at a few hundred unread posts, scroll for ten minutes, mark all as read, feel vaguely guilty. Every feed was worth following in theory. In practice I couldn't tell which five posts actually mattered for my work without reading all three hundred.

I didn't want more content. I wanted an agent that reads everything and hands me the handful of posts worth my time, with summaries. So I started building one. Feed ingestion first, then clustering to spot what was moving, then ranking against my interests, then summaries.

Somewhere in the middle of that build I noticed something. Topic selection, relevance judgment, summarizing, scheduling. My little reading tool was doing editorial work.

## Can AI Replace a Tech Editor

Before I moved into infrastructure work I was a tech and game editor. Every editor picked topics, wrote their own pieces, edited their own copy, held themselves to the style guide and shipped on schedule, and the only person above us was the editor-in-chief. When I saw my RSS agent picking topics on its own, the obvious experiment wouldn't leave me alone. Could I rebuild my old job as software, on the DevOps beat this time, and would the output survive my own editorial standards?

So the reading tool became a newsroom. Articles have to score 9.1 out of 10 against a rubric before they're allowed to ship, and plenty get rejected. A dedup gate stops the site from quietly rewriting its own archive. The style rules ban the fingerprints editors now spot instantly in AI text, the em dashes, the overused AI vocabulary, the inflated transition phrases. And the site says openly that AI writes the articles, under a named editor identity, because pretending otherwise is exactly the kind of thing an editor exists to kill.

That last rule matters more than it looks. The experiment was never "can I trick readers". It was "can the machine meet the editorial bar I hold my own writing to".

## What a Self-Running AI System Actually Looks Like

There is no server anywhere in this system. Nothing to patch, nothing to reboot, no monthly bill.

The site itself is Astro, built and hosted on [Cloudflare Pages](https://developers.cloudflare.com/pages/). The brain is a set of scheduled jobs, [GitHub Actions cron workflows](https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/events-that-trigger-workflows) for the deterministic work and scheduled Claude routines on claude.ai for everything that needs judgment.

The loop runs almost entirely without me, with one deliberate exception I will get to. Trend discovery finds candidate topics and queues them. Each weekday a content routine picks from the queue, writes, scores against the rubric, then either opens a pull request with the passing draft or rejects it outright. Nothing goes public until I merge that PR, the same review gate its own code changes pass through. Once I merge, a distribution workflow fans the article out across X, Bluesky, Reddit and Dev.to, and a weekly digest is auto-drafted for the newsletter, which is switched off for now. Site and social analytics come back after each run. Once a week an improvement analyst reads those numbers plus competitor snapshots and proposes changes. Accepted proposals become goals in a queue, and a nightly autodev lane picks up goals, opens pull requests and merges the safe ones when CI is green, the same green-pipeline discipline I use for [infrastructure code](/posts/production-ready-terraform/). Observe, decide, act, verify. An experiment ledger keeps everyone honest, and every change eventually gets marked confirmed, rejected or inconclusive.

![Self-improving loop that runs DevOps Start end to end: observe, decide, act and verify](/images/ai-system-that-improves-itself/self-improving-loop.webp)

The observe step reads more than page views. It also pulls the likes and views on each social account, so the loop can see what actually landed. I'll be honest though, I run zero marketing, so the social numbers are still too thin to conclude much from. Most of what the system learns today comes from the content itself and the competitor snapshots, not the crowd.

I started with DeepSeek through OpenRouter doing the writing. It was cheap and it was fine, just lower quality. Two LLM stacks meant twice the moving parts, so article writing moved to Claude routines. Because I already pay for Claude Max, running them adds nothing on top of a subscription I use every day anyway. If I ever wanted the bill to be a hard zero, I could drop back to the free OpenRouter models I started with and take the quality hit. The target end state is zero direct API calls, just deterministic Python and scheduled routines on that subscription.

Infrastructure cost so far, zero dollars. This blog you're reading runs on a similar no-server idea (S3 behind CloudFront), which I wrote about in my [Cloud Resume Challenge post](/posts/cloud-resume-challenge/), so the pattern isn't new to me. What's new is everything on top of the hosting.

And that short list really is the whole stack. Claude for the judgment, GitHub Actions for the scheduling, Cloudflare for the hosting, and nothing else bolted on. No orchestration platform, no vector database, no pile of a hundred bespoke tools, no thousand-line skill files spelling out every move the agent can make. I keep hearing that serious agent work needs an elaborate toolbelt, and my experience has been the opposite. The smaller the stack and the shorter the instructions, the less context each run has to carry, and small context is what keeps these routines cheap, fast and reliable. A simple SDLC isn't a limitation here. It's the reason the thing runs at all.

## Handing the Keys to the Machine

Building it with AI was the easy half. Plenty of people have done that part. The real experiment was maintenance, because maintenance is what kills side projects. You ship something in a burst of energy, life gets busy, the backlog rots and eighteen months later you archive the repo.

So I stopped being the developer. When I have free time, sometimes twenty minutes on a weeknight, I write a plan. Not code, a plan. It goes into the goal queue with a risk label. At night the autodev lane drains the queue, opens a pull request per goal and merges the low-risk ones itself on green CI. Risky ones wait for my review, and so does each day's article, which lands in the same queue as one more pull request. My merge finger is the throttle for the whole system. When I'm slammed for two weeks, nothing breaks and nothing rots. The queue just waits.

That inversion changed how much project I can afford. The hours I do spend are all judgment and no typing, the only part that still needs a human. Everything else, the writing, the testing, the distribution, the analytics collection, happens while I sleep or sit in meetings.

### What broke first

The first fully unattended run hung for hours. Root cause: the routine needed a documentation lookup that popped an interactive permission prompt, and there was nobody at the keyboard to click allow. The fix was boring and very DevOps. Preauthorize the tools, add a hard rule that unattended runs must never wait on a human, require every run to end with a Slack message even when it fails.

Another lesson looked the same in shape. No run trusts its own memory, only files on disk. Each routine reads a small state file when it starts and writes one when it finishes, so what the last run learned is a durable artifact rather than something held in context: a dedup ledger, a run log, and a handoff file the next stage reads. The order matters more than it sounds. The durable state gets written after the side effect succeeds, not before, because a crash in between would mark the work as done and make every future run skip it. Each routine keeps this logic in its own skill file, and that small discipline is why the queue can sit untouched for two weeks and still resume exactly where it left off.

In my experience the hard part of autonomy is never the intelligence. It's the operational guarantees around it. Timeouts, idempotent retries, a notification for every terminal state, a documented rollback for every risky change. Unattended AI is an SRE problem wearing a content hat, and my day job prepared me for it better than any prompt guide did.

## What the Experiment Proved

Did AI replace the tech editor? Not quite, and I hold a stronger version of that opinion than most people writing about AI content. AI took over the writing half of my old job and promoted me to the one chair I never held back then, editor-in-chief of a one-person newsroom. Every rule in that pipeline, the quality bar, the dedup gate, the banned-phrase list, the disclosure policy, is an editorial judgment I encoded once instead of enforcing on myself every single day. The taste is still mine. The machine applies it with a consistency I never managed when the writing was mine too.

The part I didn't expect is that the site's most valuable reader is me. It was born as a machine to filter RSS for one person, and it still is one. Every weekday it hands me a researched, quality-gated article about a DevOps topic that's currently moving, and reading that pull request before I merge it is how my own site briefs me on my own field. I've learned more Flux, eBPF and GitLab troubleshooting from reviewing my robot's output than I did from three years of feed scrolling.

And the skills compound outside the project. Multi-agent orchestration, prompt and routine engineering, treating LLM runs like production workloads with budgets, gates and alerts. That's my toolkit at my full-time DevOps engineer job now. When a team wants to automate something with AI and asks what breaks in practice, I answer from operating experience, not from a blog post I read. A side project that cost nothing but spare-time planning sessions turned into a professional edge I use every week. I've been collecting the resources that shaped that toolkit into a curated list, [Awesome Agentic Engineering](https://awesomeagenticengineering.com), and it runs on the same pattern as this site: a weekly agent [opens pull requests](https://github.com/fatihkc/awesome-agentic-engineering) suggesting new entries and I review them before merging.

## What I Own Now

The durable asset isn't the website. It's the capability. I now know, from operating one, how to build a system that observes its own results, decides what to try, acts on it and verifies whether the change worked. The goal queue, the routine harness, the experiment ledger, the guardrails, all of that carries straight to the next project. I won't start from zero. I'll start from a machine that already runs and point it at something new.

Where does it point? It gets sharper the moment you wire real engineering tools into its act-and-verify loop, the linters and security scanners I already trust running inside the loop instead of waiting for me to read a report. The target I actually want is an SRE agent. Point it at production, let it watch the same signals I do, and it catches a regression or a creeping cost and opens the fix as a pull request before I've even noticed the problem.

That's where this goes next, and it's a lot more interesting than one more website. I'm not announcing a product, because the point was never a single destination. It was owning a machine I can aim at the next one.

What I do know is this. Dashboards and retrospectives only tell you about the world that already happened. At some point you have to run an experiment that can fail, and the cheaper you make experiments, the more directions you get to test. DevOps Start was one deliberate test of a new direction, run for zero dollars and almost none of my time, and it paid out in knowledge, in a reusable system and in a story worth telling.

The next hypothesis is already in the queue.
