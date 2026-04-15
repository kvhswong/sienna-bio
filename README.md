# Sienna Wong - Poet Personal Website

A single-page personal website for poet Sienna Wong, hosted on AWS S3 with CloudFront.

**Live site:** https://sienna-wong.boxofwhite.com

## Tech Stack

- **Frontend:** Plain HTML, CSS, JavaScript (no frameworks, no build step)
- **Hosting:** AWS S3 (static website hosting) + CloudFront (CDN, HTTPS, security headers)
- **Infrastructure:** Terraform
- **CI/CD:** GitHub Actions
- **Fonts:** Google Fonts (Cormorant Garamond, Inter)

## Project Structure

```
.
├── index.html          # Single-page site with semantic HTML and SEO meta tags
├── styles.css          # Design system, layout, animations, responsive styles
├── script.js           # IntersectionObserver for scroll-triggered reveal animations
├── img/
│   ├── profile.jpeg                                # Profile photo (original)
│   ├── profile.webp                                # Profile photo (optimised)
│   ├── writing-from-the-end-of-the-world-cover.png # Book cover (original)
│   ├── writing-from-the-end-of-the-world-cover.webp# Book cover (optimised)
│   ├── my-story-my-vision-cover.png                # Book cover (original)
│   └── my-story-my-vision-cover.webp               # Book cover (optimised)
├── main.tf             # Terraform config (S3, CloudFront, ACM, IAM)
└── .github/
    └── workflows/
        └── deploy.yml  # GitHub Actions deploy pipeline
```

## Design

### Aesthetic

Soft and poetic — muted pastels, gentle gradients, and a literary feel that harmonises with the warm autumn tones of the profile photo.

### Color Palette

| Token        | Value     | Usage                          |
|-------------|-----------|--------------------------------|
| Cream       | `#FAF6F1` | Page background                |
| Warm White  | `#FFFDFB` | Card/section backgrounds       |
| Blush       | `#F2E0D4` | Accent backgrounds, dividers   |
| Terracotta  | `#C4886D` | Primary accent (links, buttons)|
| Amber       | `#D4A96A` | Secondary accent               |
| Sage        | `#B5BFA4` | Tertiary accent                |
| Espresso    | `#3B2F2F` | Primary text                   |
| Charcoal    | `#5C4F4F` | Secondary text                 |

### Typography

- **Headings:** Cormorant Garamond (serif) — elegant, high-contrast, literary
- **Body:** Inter (sans-serif) — clean, modern, legible
- Fluid type scale using CSS `clamp()` for responsive sizing

### Page Sections

1. **Hero** — full viewport height, rectangular profile photo with rounded corners, organic watercolor blob shapes drifting in the background, animated scroll indicator
2. **About / Bio** — two-column layout on desktop (bio text + pull-quote), stacks on mobile
3. **Published Work** — book cards with cover images and links, plus a list of individual poem links
4. **Poetic Interlude** — atmospheric gradient section with a centered poem excerpt
5. **Footer** — minimal name and copyright

### Animations

- **On-load:** Hero photo fade-in + scale, staggered text fade-in, bouncing scroll indicator
- **Scroll-triggered:** `.reveal` class with IntersectionObserver — fade-in + translateY on section elements
- **Hover:** Subtle lift on book cards/links, gentle glow on photo
- **Background:** Floating watercolor blob shapes with CSS `filter: blur()` and slow drift animation
- **Accessibility:** All animations respect `prefers-reduced-motion: reduce`

### Performance Optimisations

- Images converted to WebP with `<picture>` tag fallbacks (60–89% size reduction)
- Hero image preloaded via `<link rel="preload">`
- `width`/`height` attributes on all images to prevent layout shift
- HTML, CSS, and JS minified in the CI pipeline before deploy
- S3 cache headers: 1 year for assets, 10 minutes for HTML
- CloudFront gzip compression enabled

### SEO

- Semantic HTML (`<header>`, `<main>`, `<section>`, `<article>`, `<footer>`)
- Single `<h1>` with proper heading hierarchy
- Meta tags: description, author, theme-color, canonical URL
- Open Graph tags (`og:type=profile`) for social sharing
- Twitter Card tags (`summary_large_image`)
- JSON-LD structured data: `Person` schema + `Book` schemas
- Descriptive `alt` text on all images

### Security Headers (via CloudFront)

- **Content-Security-Policy** — XSS protection + Trusted Types
- **Strict-Transport-Security** — HSTS with preload
- **Cross-Origin-Opener-Policy** — origin isolation
- **X-Frame-Options: DENY** — clickjacking mitigation
- **Referrer-Policy** — strict-origin-when-cross-origin
- CSP also set via `<meta>` tag in HTML as defense in depth

## Infrastructure

Terraform manages all AWS resources:

- **S3 bucket** with all public access blocked
- **CloudFront Origin Access Control (OAC)** — only CloudFront can read from the bucket; direct S3 access is denied
- **CloudFront distribution** with HTTPS redirect, gzip compression, and security response headers
- **CloudFront function** to rewrite URIs to `index.html` (replaces S3 website hosting's index document feature)
- **ACM certificate** for `sienna-wong.boxofwhite.com` with DNS validation
- **IAM policy** scoped to the S3 bucket and CloudFront distribution

### CI/CD Pipeline

On every push to `main`, GitHub Actions:

1. Minifies HTML, CSS, and JS
2. Syncs assets to S3 with long cache headers (1 year)
3. Uploads `index.html` with short cache headers (10 minutes)
4. Invalidates the CloudFront cache

## Manual Setup Steps

The following steps were performed manually and are not automated by Terraform or GitHub Actions.

### 1. AWS Credentials

Create an IAM user in the AWS console and generate access keys. Attach the `sienna-wong-website-deploy` IAM policy (created by Terraform) to this user.

### 2. DNS Configuration

Two CNAME records were added to the DNS for `boxofwhite.com`:

**ACM certificate validation:**

| Name | Type | Value |
|------|------|-------|
| `_****6d6ff.sienna-wong` | CNAME | `_****bfb3b.jkddzztszm.acm-validations.aws.` |

**Route traffic to CloudFront:**

| Name | Type | Value |
|------|------|-------|
| `sienna-wong` | CNAME | `[terraform output cloudfront_distribution_id].cloudfront.net` |

The ACM validation CNAME must be in place before `terraform apply` can complete — Terraform will pause at `aws_acm_certificate_validation` until DNS propagates (typically 1–5 minutes).

### 3. GitHub Repository Secrets

The following secrets were added at **Settings > Secrets and variables > Actions**:

| Secret Name | Description |
|-------------|-------------|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `CLOUDFRONT_DISTRIBUTION_ID` | CloudFront distribution ID (from `terraform output cloudfront_distribution_id`) |

## Local Development

Open `index.html` directly in a browser, or start a local server:

```bash
python3 -m http.server 8080
```

Then visit http://localhost:8080.

## Deploying Infrastructure Changes

```bash
terraform init    # First time only
terraform plan    # Review changes
terraform apply   # Apply changes
```

## Content Updates

To update bio text, quotes, or links — edit `index.html` and push to `main`. The GitHub Actions pipeline will automatically minify, deploy to S3, and invalidate the CloudFront cache.
