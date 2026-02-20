# The People's Scoreboard

A web app for organized economic activism — users log unsubscriptions and boycotts from companies enabling ICE/Trump policies. Collective action counts are shown publicly; per-user history is available when logged in.

> Built as a learning project using Claude Code, with a genuine hope of making an impact.

---

## Stack

| Layer | Tech |
|-------|------|
| Frontend | HTML + Tailwind CSS (CDN) + Alpine.js (CDN) — no build step |
| Backend | AWS Lambda (Python 3.12) + API Gateway |
| Database | DynamoDB (on-demand) |
| Auth | Cognito (passwordless EMAIL_OTP) |
| Hosting | S3 + CloudFront |
| Infra | Terraform |

---

## Features

- **Public scoreboard** — global action counter (10-digit, comma-formatted) + per-company counts
- **Leaderboard** — ranked list of users by total actions taken (emails masked)
- **Passwordless sign-in** — email OTP, no password ever set or stored
- **One vote per action** — DynamoDB conditional writes prevent duplicate counting
- **CloudFront caching** — public API endpoints cached at the edge (60s for counts, 5min for leaderboard)

---

## Auth Flow

All authentication is handled in `login.html` via direct Cognito API calls — no Hosted UI.

**New user:**
1. Enter email → Cognito `SignUp` → 6-digit verification code sent
2. Enter code → account confirmed → 8-digit OTP sent automatically
3. Enter OTP → signed in

**Returning user:**
1. Enter email → Cognito `InitiateAuth` → 8-digit OTP sent
2. Enter OTP → signed in

Tokens are stored in `sessionStorage` and sent as the `Authorization` header on protected API calls.

---

## Quick Start (Local Dev)

There's no build step — open the HTML files directly or serve with any static server:

```bash
cd frontend
python3 -m http.server 3000
# visit http://localhost:3000
```

Note: Auth and API calls will still hit the deployed AWS backend.

---

## Deploy

### Prerequisites
- AWS CLI configured
- Terraform >= 1.0

### First-time setup
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars — set aws_region and environment
terraform init
terraform apply
```

### Deploy frontend
```bash
./deploy-frontend.sh   # syncs frontend/ to S3 + invalidates CloudFront
```

### Outputs after `terraform apply`
| Output | Description |
|--------|-------------|
| `cloudfront_domain` | Public URL of the app |
| `api_endpoint` | Direct API Gateway URL (bypasses CloudFront cache) |
| `cognito_user_pool_id` | Cognito pool ID |
| `cognito_client_id` | App client ID used in `js/auth.js` |
| `s3_frontend_bucket` | S3 bucket name |

---

## Project Structure

```
frontend/
  index.html          # Main page — tabs, global counter, action buttons
  profile.html        # Per-user activity history
  login.html          # Sign in + sign up (single page, OTP flow)
  js/auth.js          # Auth helpers: OTP functions, token storage, API helper

terraform/
  lambda_src/
    log_click.py          # POST /log-click
    get_click_count.py    # GET /click-count
    get_user_activity.py  # GET /user-activity
    get_user_votes.py     # GET /user-votes
    get_leaderboard.py    # GET /leaderboard
  cognito.tf            # Passwordless user pool + app client
  dynamodb.tf           # click-log + click-dedup tables
  lambda.tf             # Lambda functions + IAM
  api_gateway.tf        # Routes + CORS + Cognito authorizer
  s3_cloudfront.tf      # Static hosting + API caching
  variables.tf / outputs.tf / main.tf
```

---

## API

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/log-click` | Cognito JWT | Record an action |
| GET | `/click-count?button_id=` | None | Count for one button |
| GET | `/user-activity?limit=` | Cognito JWT | Caller's action history |
| GET | `/user-votes` | Cognito JWT | Buttons caller has voted on |
| GET | `/leaderboard` | None | All users ranked by action count |

All requests go through CloudFront (`https://dmmywcvdfo0fv.cloudfront.net`). Public endpoints are cached at the edge; authenticated endpoints bypass the cache.

---

## Tear Down

```bash
cd terraform && terraform destroy
```
