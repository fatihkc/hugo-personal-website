# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal website / blog for **fatihkoc.net**, built with **Hugo** (hugo-coder theme) and hosted on AWS (S3 + CloudFront + Route53 + ACM). Infrastructure is managed with Terraform; CI/CD runs on GitHub Actions; Cypress smoke-tests the live production site after each deploy. Content is DevOps/SRE/cloud focused.

Three loosely-coupled parts, each with its own workflow:
- `site/` — the Hugo site (content, config, theme, custom layout overrides)
- `terraform/` — the AWS infrastructure that hosts it
- `e2e/` — Cypress tests that run against **production** (`https://fatihkoc.net`)

## Commands

Hugo commands take `--source site` when run from the repo root. Local Hugo must be the **extended + withdeploy** build (Homebrew's `hugo` includes both); CI pins `0.154.2` — keep local and CI versions aligned.

```bash
# Local dev server → http://localhost:1313
hugo server --source site

# Production build (output goes to site/public/, git-ignored)
hugo --source site --minify

# Terraform (state in S3 + DynamoDB; requires AWS creds)
terraform -chdir=terraform fmt -recursive
terraform -chdir=terraform validate
terraform -chdir=terraform plan
terraform -chdir=terraform apply

# E2E (Cypress 15) — defaults to production
npm --prefix e2e install                       # first time
npm --prefix e2e run cy:run                    # headless, all specs
npm --prefix e2e run cy:open                   # interactive
cd e2e && npx cypress run --spec cypress/e2e/homepage.cy.js   # single spec
CYPRESS_BASE_URL=http://localhost:1313 npm --prefix e2e run cy:run  # against local hugo server (dev convenience only)
```

## Deployment (how the site ships)

Driven by Hugo's built-in `[deployment]` block in `site/config.toml`, not `aws s3 sync`. On push to `main` touching `site/**`, `e2e/**`, `scripts/**`, or the workflow file, `.github/workflows/site.yml`:
1. Injects the Google Analytics ID by `sed`-replacing `#id =` in `config.toml` (comes from the `GOOGLEANALYTICS` secret; never stored in the repo).
2. Installs Hugo from the official `hugo_extended_withdeploy_*` release tarball — **since Hugo 0.139, `hugo deploy` only exists in the `withdeploy` build variant**, and setup actions like peaceiris/actions-hugo can't install it. Don't "simplify" this back to an action.
3. Builds with `hugo --minify`, then `hugo deploy --force --invalidateCDN` (S3 sync + CloudFront invalidation; cache-control/gzip/content-type rules live in `config.toml`'s deployment matchers).
4. Runs `scripts/submit-indexnow.sh` (pushes sitemap URLs to IndexNow/Bing).
5. Runs Cypress **against production, post-deploy**. This is a deliberate owner decision — e2e validates the live site, not a local build. Do not add pre-deploy/local-server test jobs.

The Terraform workflow (`.github/workflows/terraform.yml`) is manual-only (`workflow_dispatch`) and effectively **plan-only**: the apply step's condition requires a push event that never occurs. Applies are run locally on purpose.

## Architecture notes that span multiple files

- **Theme is a git submodule** (`site/themes/hugo-coder`); CI checks out with `submodules: true`. Never edit theme files — override via `site/layouts/`.
- **Custom layout overrides** in `site/layouts/`: `index.html`/`index.xml` (home + RSS), `_default/about.html`, `partials/head/extensions.html`, `partials/head/theme-styles.html`, `partials/head/custom-icons.html`, and `partials/home/recent-posts.html`. `head/extensions.html` hand-builds **schema.org JSON-LD** (Person, WebSite, BlogPosting, BreadcrumbList) per page type — check it when changing site metadata, social links, or post front-matter.
- **The home page stacks profile over latest-posts**, and that needs `site/assets/css/home.css` (wired via `params.customCSS`). The theme's `.content` is `display: flex` with no `flex-direction` — a row that assumes exactly one `.container` child. `index.html` gives it two (the theme's `home.html` plus `partials/home/recent-posts.html`), so both are wrapped in `.home-content`, which sets `flex-direction: column` to stack them and `flex: 1` so the wrapper fills `.content` (without it the wrapper shrinks to its contents and `width: 100%` on `.container` has nothing to resolve against). Posts go **under** the profile, not beside it — that's a deliberate owner preference, so don't "fix" it back to two columns. Don't add further children to `.content` without checking this. Note `customCSS` injects its `<link>` into **every** page, not just the home page.
- **Terraform module versions are pinned for a reason**: `terraform-aws-modules/cloudfront` is pinned `~> 5.0` because **v6 removed OAI support**, which this config depends on. Unpinning breaks every fresh `terraform init`. Bumping to v6 means doing the full OAI→OAC migration (module + `aws_s3_bucket_policy` in `s3.tf` together).
- **Two AWS providers**: default `eu-central-1`, plus aliased `us-east-1` (`provider.tf`) required for CloudFront's ACM certificate. Files map to concerns: `s3.tf`, `cdn.tf`, `acm.tf`, `route53.tf`, `backend.tf`, `versions.tf`, `variables.tf`.
- **S3 is fully private**; CloudFront reaches it via OAI over the REST endpoint. Directory-index rewriting and www→apex redirects happen in a CloudFront Function (`terraform/scripts/redirect.js`, `cloudfront-js-2.0` runtime) — there is intentionally no S3 website hosting config.
- **Font Awesome is subsetted, and that spans four places.** The theme ships the full FA6 web fonts (~300 KB across three faces) and preloads all of them. This repo cuts that to ~3 KB, which requires all of: (1) `scripts/subset-fontawesome.py`, run **by hand**, writing subsetted `.woff2` into `site/static/fonts/` — those shadow the theme's identically-named files in Hugo's static union, which is why the URLs never change; (2) SCSS overrides in `site/assets/scss/font-awesome/` that shadow the theme's partials to emit ~20 icon classes instead of 833, drop the regular face and the v4 shims, and reference woff2 only; (3) `partials/head/theme-styles.html`, which preloads two faces instead of three; (4) FA6 class names in `config.toml`'s `[[params.social]]`, since the v4 shims that used to translate `fa fa-linkedin` are compiled out. **`$site-fa-icons` in `assets/scss/font-awesome/_icons.scss` is the single source of truth** — the script parses it. Add an icon there and re-run the script, or the class resolves to a glyph the font no longer contains and renders a blank box. The script refuses to run if the two disagree, and separately checks the icons the theme injects from CSS via `fa-content()` (`external-link`, drawn on every outbound link in every post, appears in no HTML markup at all).
- **Deployment matchers are first-match-wins.** `[[deployment.matchers]]` in `config.toml` is evaluated in order, so the specific filename rules (`^site\.webmanifest$`, `^sitemap\.xml$`) must stay above the general extension rules. Long `Cache-Control` is applied to non-fingerprinted paths (`/images/...`, `/fonts/...`) as a deliberate trade-off: replace such a file under a **new filename** rather than in place.
- **CSP is defined in Hugo config** (`[params.csp]` in `config.toml`), not infra. New external scripts/fonts/styles must be added to the matching directive or they're blocked.

## Content authoring (site/content/)

- **New posts are drafted locally and never pushed until Fatih explicitly says to publish.** The repo is public, so anything pushed — branches, PRs, intermediate commits — is permanently visible on GitHub (even after squash-merge or branch deletion). Write the post on a local branch with `draft = true` in front-matter, preview with `hugo server --source site -D`, commit locally as often as needed. Only on Fatih's explicit "publish" instruction: remove `draft = true`, collapse the WIP commits into one clean commit (e.g. `git reset --soft main`, commit fresh), push, open a PR, and merge to `main` — merging deploys the post.
- Blog posts are flat files: `site/content/posts/<slug>.md`. Front-matter is **TOML** (`+++`) with `title`, `description`, `date`, `author`, `tags` — the default archetype emits YAML, so match existing posts instead.
- Post images live under `site/static/images/<slug>/`, referenced as `/images/<slug>/...`. Prefer WebP; hero/featured images are **1200×630 WebP** (Open Graph).
- Optional writing-style reference at `../personal-gpts/writer.txt` (outside the repo) — consult when drafting blog prose if present.

## Non-obvious facts (look wrong, aren't)

- The GA/GTM ID is absent from `config.toml` by design — CI injects it (see Deployment). Don't add it.
- `site/static/fonts/fa-solid-900.woff2` and `fa-brands-400.woff2` are **2 KB and 1 KB, not corrupt truncations** — they are generated subsets that intentionally shadow the theme's full-size copies of the same names. The theme's `.ttf` files and `fa-regular-400.woff2` still deploy to S3 as dead weight; nothing references them, and Hugo offers no way to exclude a theme's static file.
- `site/static/9968e047….txt` (IndexNow verification key) is **intentionally public and committed** — the protocol requires it. It is not a leaked secret.
- The Terraform apply gate in `terraform.yml` never fires — intentional; see Deployment.

## Known follow-ups (deferred, not forgotten)

- OAI → OAC migration (unlocks CloudFront module v6; change bucket policy and distribution together).
- Replace long-lived AWS access keys in Actions with OIDC.

## Conventions

- **Never commit directly to `main`** — every change, including docs, goes through a branch and a PR.
- **Planning docs are temporary.** Design specs and implementation plans (e.g. `docs/superpowers/specs/`) are local working artifacts: keep them on the working branch while the work is in flight, delete them once that work ships, and never let them reach `main` or a publish commit.
- **Conventional Commits** (`feat:`, `fix:`, `chore:`, `test:`, `ci:`, …), one PR per logical change.
- Terraform or workflow changes: include what/why/rollback in the commit or PR body; run `fmt` and `validate` first; verify `terraform plan` is clean after applying. No hard-coded ARNs/IDs — use variables and data sources.
