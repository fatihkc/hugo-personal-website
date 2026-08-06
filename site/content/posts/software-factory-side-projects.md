+++
title = "I'm Building a Software Factory That Turns My Issues Into Merged Code"
description = "I'm building a software factory that turns planned GitHub issues into merged code, so my side project time goes to planning instead of writing the code myself."
date = "2026-08-06"
author = "Fatih Koç"
tags = ["AI", "DevOps", "Automation"]
images = ["/images/software-factory-side-projects/software-factory-side-projects.webp"]
featuredImage = "/images/software-factory-side-projects/software-factory-side-projects.webp"
+++

I call it the factory. I write a plan into a GitHub issue and label it `ready`. A run picks it up, cuts a worktree, writes the code, runs the tests and opens a pull request. Some of those it merges without me now, under conditions I'll come to.

A software factory for exactly one person, which is either a good name or a slightly grand one for something that runs on my laptop. It's private, it isn't a product and there's nothing to sign up for. It moves my side project time from writing the code to planning it, and the parts that broke turned out to be more interesting than the parts that worked.

## Why I Stopped Writing My Own Side Projects

Side projects don't die of bad ideas. They die of maintenance.

Here's what changed for me. On a normal weeknight I have about half an hour. That's enough to think clearly about one problem and write down the right fix. It's nowhere near enough to implement it, run the tests, fix what broke and open a pull request. So the planning always got done and the building never did.

That asymmetry is the entire reason the factory exists. My scarce resource was never ideas and it was never judgment, it was implementation time. Deciding what to build and what it must not break is engineering. Turning that decision into working code is labor, and I've done it long enough to know I add little by doing it personally. So I kept the first half and gave away the second.

### What I tried first, and why it broke

I didn't start by building any of this. The first version was a task queue plus a nightly autodev routine in the cloud, and pointed at one project it worked fine. It took a goal off the list, wrote the code and opened a pull request while I slept.

It came apart when I pointed it at a second project. The queue lived in one place and the repositories in another, so keeping the two in step became a job of its own. A goal would be marked done while the repo said otherwise, and every extra project multiplied the ways that could happen. I spent more time reconciling the queue than the routine had saved me.

That failure is the reason for almost every design decision below. If a queue can disagree with the project it describes, sooner or later it will. The only fix that holds is to not keep a second copy at all.

## What One Run of the AI Coding Agent Actually Does

So the queue is GitHub Issues, and nothing else. No database, no board, no separate task file. The state of a task is the label sitting on it, in the same place the code lives, and every view is derived from that. There's only one copy to read, so nothing can disagree with anything.

An issue joins the queue when I put the `ready` label on it. That label is the whole interface, and it doesn't mean I want the thing. It means the body is a plan I agree with. Nothing turns an issue into a plan on its own. Some arrive that way, written clearly enough when I filed them that there's nothing left to decide. The rest I talk through with Claude in the chat UI until the decisions are made and written into the body, and the label goes on after that, never before. Everything downstream reads that body as the spec, so a vague issue produces vague code, and that's on me.

The one page I look at is the floor, a column per label and nothing of its own. It renders GitHub and the run folders on disk, so it can't disagree with them. Most days it looks like this.

![The floor view, showing the label columns a task moves through](/images/software-factory-side-projects/factory-floor-queue.webp)

From there a run does the whole job and exits. It cuts a [git worktree](https://git-scm.com/docs/git-worktree) fresh from `origin/main`, so my own checkout is never touched and a stale clone can't build on old code. It copies the issue body to disk as the spec, because no model should write what a human already wrote. It plans against the repo's own rules, with a verdict on each, before any code exists. Then it writes the code and runs the gate: the test command, then every line of the issue's definition of done, verbatim. It ends with a draft pull request saying `Closes #180` and a record of turns, wall clock and cost, which is what the ledger reads later.

![How a task moves from a planned issue to merged code, with landing as a separate turn](/images/software-factory-side-projects/issue-to-merged-flow.webp)

Green ships. Red also opens a draft pull request, marked `needs-review` and carrying the failure, because either way a person is needed and hiding it helps nobody. A run that ships deletes its worktree. A run that fails keeps it, because a failed run is evidence.

Each stage can name its own model and how hard it thinks, and I used that to split them. Reading a codebase and arguing about an approach looked like cheaper work than writing code that keeps a suite green, so the reading stages ran somewhere cheaper.

I had it backwards. Planning is where a bad decision gets expensive: the plan is what implementing is graded against, so a flaw there survives every gate downstream, while a weak line of code fails the suite and gets caught. The split runs the other way now. The strongest model I have reads and argues, and writing the code stays on Opus.

```toml
[stages.plan]
model = "fable"
effort = "high"

[stages.implement]
model = "opus"
effort = "high"
```

Paying the most for the stage that writes no code is the part that looks odd, which is why it's worth naming out loud. Leaving both blank would hand the choice to whatever the provider defaults to that month, and the run record says which model did which stage, so I can judge it rather than assume it.

## Every Gate Is Deliberately Dumb

Not one of the checks that decides whether the work is good asks a model anything. The gate is the test suite, ruff for style and mypy for types, in a single command. All deterministic, all free to run once written, and none of them can be talked into passing. The security scan sits deliberately outside it, in CI, because it fetches its rule packs over the network and a run shouldn't fail for a reason the change didn't cause. One of those packs looks for hardcoded credentials, and since a landing turn refuses on a red check, that's a class of leak the loop can't merge past.

That last part is the one I care about most. Ask a model whether the code it just wrote is correct and you're asking a question it has an obvious interest in the answer to. I'd rather ask something with no opinion. The cost argument is just as real: an AI judge bills tokens on every run, forever, including the runs that were fine, while a test suite is a fixed cost paid once. Run a loop several times a day and that's the difference between a habit and a bill. It's the same discipline I already trusted in infrastructure work, where I'd much rather have a [pipeline that blocks a bad Terraform change](/posts/production-ready-terraform/) than a reviewer who is supposed to notice it.

One rule makes it concrete. A claim that something passed has to carry the command and its output, and a gate that can't be graded is a failed gate rather than a passed one. I wrote that after shipping a gate that was fake for three runs and looked green the whole time.

## What It Merges Alone, and What Waits for Me

For its first days the factory never merged anything, which was the right default until there was a record to argue from. What that record showed was that on the small changes the review step contributed nothing but the hours between the work finishing and me getting to it. So small improvements land now, and work that could break something waits for me.

Merging is allowed, but never by the run that did the work. A landing turn is a separate run on its own clock, and that separation is the design decision I'd defend hardest. The turn that judges whether work is good must not be the turn that declares it finished. A run that just spent forty turns convincing itself its change is correct is the worst possible candidate to also decide it ships. And when a run ends, CI hasn't answered yet.

A landing turn stops at the first of four guards that doesn't hold: the gate passed on the record committed to the branch, CI green, no fenced path touched, and nobody else on the pull request. Two of those carry the weight. Fencing matters because a run that can edit the rules it's graded against isn't gated at all. And CI being green is not the same as CI having run: a branch that conflicts with its base produces no merge reference, so no checks run at all, and an empty check list read as "nothing failed" merges a conflict. A repo with no CI therefore merges nothing automatically, which is the safe default rather than an oversight.

Waiting is the default and landing is the exception. The factory merges what's safe and holds what isn't, and what it holds, I read. It also has an off switch with a written trigger: one landed change that breaks the default branch and it goes back to never merging, until the guard that would have caught it exists and has a test.

## What Broke, and What It Taught

Almost everything worth knowing came from running it, not from testing it. The suite was green through every failure below, at five hundred tests then and past twelve hundred now. The worst day produced four greens that meant nothing.

- A stale runtime image shipped a pull request built from code that predated the stage meant to test it.
- A frozen clone quietly stopped the ledger listing new runs.
- A UI container fourteen hours stale had me file an issue for a bug that was already fixed.
- A second copy of the config meant a model change I made never reached what actually ran.

Four different bugs, one shape, and the same shape that killed the first version. **Anything with two copies drifts.** The image and the source, the clone and the remote, the config in the repo and the config on the host, the queue and the project. Every one looked green while being wrong, which is the only kind of failure that really costs you.

Two more were expensive in time. Turn ceilings, eight in a single day. Not one was a capability problem and every one was a sizing problem. "Add these two tools and fix everything they flag across the tree" is two tasks wearing one issue, and a human would have split it without thinking. The fix was never a bigger ceiling, it was smaller issues. An empty queue cost a day the same way: turns that found no work still counted against the daily cap, and nothing but an overnight run with nothing queued would have shown me that.

### The second copy I made on purpose

Building the factory with the factory was a shortcut I took with my eyes open: a tool whose only test is itself is the weakest test there is. It was the fastest way to have a real project to aim at, and it bought me weeks.

The same trade sits one level down. I run a container that mounts my working tree over the image's own code, so a change takes effect on the next run instead of after a rebuild. It's the wrong shape by my own rule, and worth it only because the loop has to be fast. What makes it survivable isn't avoiding the shortcut, it's refusing to let the shortcut lie: that container stamps its run record `working-tree` rather than a commit hash, because naming a commit that never produced the work is the drift above wearing a different coat. Scheduled runs still take a built artifact that can be dated.

A second copy is a risk you can price. What you can't survive is a second copy that claims to be the first one.

## Why I Can Afford to Let It Fail

This is the ledger, the floor's other view: every run, what its gate said, how far it got and what it cost.

![The run ledger, listing each run's gate result, stage reached, time and API-equivalent cost](/images/software-factory-side-projects/factory-runs-ledger.webp)

That USD column is the argument. Every run records what its tokens would have cost billed through the API, and they land between one and five dollars each. The failed ones cost the same as the successful ones.

On the subscription I already pay for, all of them cost nothing extra. That gap is why eight turn ceilings in one day was an annoying afternoon instead of an expensive mistake, and why I can leave a badly sized issue in the queue just to see what the failure looks like.

Cheap failure changes what you're willing to attempt. Deterministic graders keep the per-run cost near zero and a flat subscription keeps the model cost predictable, which together give me a loop I'm allowed to be wrong in.

## My Software Factory Is Still an MVP, and I'm Still Building It

It works, and it isn't finished. I'm not trying to build the perfect factory. I'm trying to build one that solves my problem and to let it change as the problem does, which is why almost everything in it exists because something broke first, and why the roadmap keeps getting reordered by whatever failed most recently.

Two things already make it a launchpad rather than one repo's tool. Adding a project is one config file and six labels. And it gets better when the models get better, with nothing for me to change.

The stack is deliberately small: the `gh` CLI and a subscription driven through [Claude Code's non-interactive mode](https://code.claude.com/docs/en/headless), on Python with nothing but the standard library. That list is short because most of what a factory needs already exists inside those two tools. GitHub is the queue, the labels, the review surface, the check results and the merge. Claude Code is the agent loop, the tools a stage can call and the permission model deciding which ones it gets. What I wrote is the glue between them: which stage runs when, what it's allowed to touch, and what has to be true before anything lands. I keep reading that serious agent work needs an elaborate platform underneath it. My experience has been the opposite, and the platform I'd have built would mostly have been a worse copy of the two I already had.

Whatever the tooling supports, a stage can use: [MCP](https://modelcontextprotocol.io/) servers, skills, the rest of it. Those are the only third parties in the loop that aren't GitHub or the model itself, so the list is a committed file passed strictly and the tools are allow-listed by name, which keeps what a stage can reach the same on my laptop as in the container.

The list of what's left is longer than I'd like, but the order matters more than the length, and the item that set that order is already behind me.

It's pointed at a second repo now. That cost a day, one config file and one real issue, against a project that already had a test suite, and the loop travels. Which is the answer I needed, because running several at once is the goal that started the whole thing and it's exactly where the first version fell over. With the loop proven to move, that's packaging rather than a rebuild. Every project runs the same gate in the same shape, with its own tests sitting behind it, which is what makes one standard across several repos a config question rather than a rewrite.

The rest is what makes several projects survivable rather than merely possible. A risk tier per change, computed from the diff and never asserted by the run that wrote it. Priority labels, because the queue takes the oldest issue first and that breaks the moment a routine files twenty overnight. Refusing an oversized issue at intake. A daily digest, because with several projects running the dominant failure mode isn't a bad merge, it's silence.

Then one constitution, a shared base plus a per-project delta, and that's the part I'd defend as the actual point. Multi-project doesn't mean N projects running at once. It means N projects built to one standard I wrote once.

The SRE agent sits behind those priority labels rather than ahead of them: a routine pointed at the errors a deployed project already produces, filing issues rather than pull requests, so the ordinary loop builds them and the ordinary guards apply. Turn it on before the queue can rank anything and it just buries the queue. I named that target when I wrote about [the AI system that runs my content site](/posts/ai-system-that-improves-itself/), which is why this loop is aimed at things rather than built into one project.

What it does not prove, because a roadmap invites more credit than the evidence supports. Unattended overnight running is still off, because a laptop that sleeps stops being a scheduler.

## What I Actually Own Now

It's one person's tool, so I won't pretend it generalizes to your team. The narrower claim is more useful anyway. Make failure cheap enough and your graders honest enough, and you can hand over the implementation while keeping the judgment. The projects that used to die of maintenance stop dying.

The queue is the project now, and writing to it is the only part I still do by hand. My half hour on a weeknight goes into it. The code shows up while I'm asleep.

Most of what sits in that queue next is work on the factory itself, so it builds itself, which is still the part I find strangest.

There's a longer game here, and I'd rather name it than let the post imply the factory is the whole idea. I'm building toward an incubator for small products, and this factory is one machine in it. A second factory already runs, a pipeline that turns public-domain artwork into short-form video. If a few of these work, together they take an idea to something people can actually use, and that could make money eventually. I'd be glad if it did. But I'm not doing this on weeknights to get rich. I want to know what one person can build right now, and the only way to find out is to build it and write down what breaks.

One open question, then. The factory is private, and it doesn't have to be. Should I open source it? If you'd run it, or you'd just want to read how it works, say so. That's the thing that would decide it.
