# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal website / blog for **fatihkoc.net**, built with **Hugo** (hugo-coder theme) and hosted on AWS (S3 + CloudFront + Route53 + ACM). Infrastructure is managed with Terraform; CI/CD runs on GitHub Actions; end-to-end smoke tests use Cypress. Content is DevOps/SRE/cloud focused.

This repo has three loosely-coupled parts, each with its own workflow:
- `site/` — the Hugo site (content, config, theme, custom layout overrides)
- `terraform/` — the AWS infrastructure that hosts it
- `e2e/` — Cypress tests that run against the **live production site**

## Commands

Hugo commands take `--source site` when run from the repo root (or `cd site` first). Local Hugo should be the **extended** build; CI pins `0.136.2`.

```bash
# Local dev server → http://localhost:1313
hugo server --source site

# Production build (output goes to site/public/, git-ignored)
hugo --source site --minify

# Terraform (state lives in S3 + DynamoDB; requires AWS creds)
terraform -chdir=terraform fmt -recursive
terraform -chdir=terraform validate
terraform -chdir=terraform plan
terraform -chdir=terraform apply

# E2E — Cypress hits the deployed prod URL, not localhost
npm --prefix e2e install         # first time
cd e2e && npx cypress run        # headless, all specs
cd e2e && npx cypress run --spec cypress/e2e/homepage.cy.js   # single spec
cd e2e && npx cypress open       # interactive
```

Note: `e2e/package.json` has no npm scripts (only the cypress devDependency), so invoke Cypress via `npx` directly. Tests hard-code `https://fatihkoc.net`, so a green run reflects production, not local changes.

## Deployment (how the site actually ships)

Deployment is driven by Hugo's built-in `[deployment]` block in `site/config.toml`, **not** a manual `aws s3 sync`. On push to `main` touching `site/**` or `e2e/`, `.github/workflows/site.yml`:
1. Injects the Google Analytics ID by `sed`-replacing `#id =` in `config.toml` (the ID is **not** stored in the repo — it comes from the `GOOGLEANALYTICS` secret at build time).
2. Builds with `hugo --minify`.
3. Runs `hugo deploy --force --invalidateCDN`, which syncs to the S3 bucket and invalidates CloudFront using the bucket URL + distribution ID configured in `config.toml`'s `[deployment.targets]` and `[deployment.matchers]` (cache-control, gzip, content-types are set there).
4. Runs `scripts/submit-indexnow.sh` to push all sitemap URLs to IndexNow (Bing).
5. Runs Cypress against production.

The Terraform workflow (`.github/workflows/terraform.yml`) is **manual only** (`workflow_dispatch`) — infra is never applied automatically. Both workflows authenticate to AWS with long-lived access-key secrets.

## Architecture notes that require reading multiple files

- **Theme is a git submodule.** `site/themes/hugo-coder` is pulled from upstream (`.gitmodules`); CI checks out with `submodules: true`. Don't edit theme files directly — override via `site/layouts/`.
- **Custom layout overrides.** `site/layouts/` selectively overrides the theme: `index.html`/`index.xml` (home + RSS), `_default/about.html` (custom About template), and `partials/head/extensions.html`. The last one is significant — it hand-builds **schema.org JSON-LD** (Person, WebSite, BlogPosting, BreadcrumbList) per page type for SEO. When changing site metadata, social links, or post front-matter, check this partial.
- **Terraform uses two AWS providers.** Default `eu-central-1` for S3, plus an aliased `us-east-1` provider (`provider.tf`) required for CloudFront's ACM certificate. Files map to concerns: `s3.tf`, `cdn.tf`, `acm.tf`, `route53.tf`, `backend.tf`, `versions.tf`, `variables.tf`. The S3 bucket blocks all public access; CloudFront reaches it via OAI, wired through `aws_s3_bucket_policy` in `s3.tf`. **Bucket policy and CloudFront OAI must be edited together.**
- **CSP is defined in Hugo config**, not infra — see `[params.csp]` in `config.toml`. If you add an external script/font/style, update the matching CSP directive or it will be blocked.

## Content authoring (site/content/)

- Blog posts are **flat files**: `site/content/posts/<slug>.md` (not page bundles). Front-matter is **TOML** (`+++ ... +++`) with `title`, `description`, `date`, `author`, `tags`. (The `hugo new` archetype emits YAML `---` — existing posts use TOML; match the existing style.)
- Static assets (post images) live under `site/static/images/<slug>/` and are referenced as `/images/<slug>/...`.
- Prefer built-in shortcodes over raw HTML; use fenced code blocks with language hints; give images accessible alt text.
- Featured/hero images: **1200×630 WebP** (Open Graph). Prefer WebP for content images generally.

## Project facts & guardrails (do not "fix" these)

- **Do not add Google Analytics / Tag Manager to config** — the GA ID is injected in CI (see Deployment).
- **Do not add `robots.txt`** — it exists at `site/static/robots.txt`.
- **Do not add `sitemap.xml`** — Hugo generates it (custom content-type set in `config.toml` deployment matchers).
- The IndexNow verification key file (`site/static/<key>.txt`) is intentionally public and committed.
- Use **Context7** to fetch current docs for Hugo, Terraform, AWS, and Cypress rather than relying on memory.
- Optional writing-style reference at `../personal-gpts/writer.txt` (outside this repo) — consult it when drafting/reviewing blog prose if present.

## Conventions

- **Conventional Commits**: `feat:`, `fix:`, `docs:`, `chore:`, `test:`, `ci:`, `refactor:`, `perf:`. Keep changes small and atomic.
- For Terraform or workflow changes, include a short what/why/rollback rationale in the commit body, and run `fmt`/`validate` first. No hard-coded ARNs/IDs — use variables and data sources.
