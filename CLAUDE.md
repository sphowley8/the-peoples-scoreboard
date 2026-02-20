# The People's Scoreboard — Claude Quick Reference

> Keep this file under 200 lines and update it whenever you add/change significant code.

## What This Is
Economic activism tracker. Users log unsubscriptions/boycotts from companies enabling ICE/Trump policies. Shows collective action counts publicly, per-user history when logged in.

## Stack
- **Frontend**: HTML + Tailwind CSS (CDN) + Alpine.js (CDN) + plain JS — no build step
- **Backend**: AWS Lambda (Python 3.12) + API Gateway + DynamoDB + Cognito
- **Infra**: Terraform (all in `terraform/`)
- **Hosting**: S3 + CloudFront

## Key Files
```
frontend/
  index.html        # Main page — tabs, counters, unsubscribe links
  profile.html      # Per-user dashboard (activity history)
  callback.html     # OAuth callback — exchanges code for tokens
  js/auth.js        # Cognito auth helpers (isLoggedIn, getIdToken, etc.)
terraform/
  lambda_src/
    log_click.py          # POST /log-click (auth required)
    get_click_count.py    # GET /click-count?button_id= (public)
    get_user_activity.py  # GET /user-activity (auth required)
    get_user_votes.py     # GET /user-votes (auth required)
    get_leaderboard.py    # GET /leaderboard (public) — scans dedup table
  lambda.tf         # Lambda functions + IAM roles
  api_gateway.tf    # All API routes + CORS
  cognito.tf        # User pool config
  dynamodb.tf       # Table definitions
```

## API Endpoints
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /log-click | Cognito | Record a user action |
| GET | /click-count?button_id= | None | Count for one button |
| GET | /user-activity?limit= | Cognito | User's click history |
| GET | /user-votes | Cognito | Buttons user has voted on |
| GET | /leaderboard | None | All users ranked by action count |

Config in `js/auth.js`: `CONFIG.apiEndpoint` = `https://zhl7evbf4i.execute-api.us-east-1.amazonaws.com/dev`

## DynamoDB Tables
- **click-log** (`peoples-scoreboard-click-log-dev`): PK=`user_id`, SK=`timestamp`. GSI on `button_id` for counting.
- **click-dedup** (`peoples-scoreboard-click-dedup-dev`): PK=`user_id`, SK=`button_id`. One vote per user per button. Leaderboard scans this table.

## Frontend Architecture

### Tab System (index.html)
Three tabs rendered via `setTab(name)` — pure JS, no Alpine.
- `why` → Scott Galloway quote / manifesto
- `unsubscribe` → Ground Zero (subscriptions) + Blast Radius (ICE enablers)
- `leaderboards` → ranked table from `/leaderboard` API

### Alpine.js Components
- `navAuth()` — nav login/logout state
- `globalCounter()` — sums all button counts on init
- `linkCounter(buttonId)` — per-button count display
- `linkAction(buttonId, targetUrl)` — handles click + logs to API
- `leaderboard()` — fetches and renders leaderboard table

### Tracked Button IDs (34 total)
Amazon (6), Apple (6), Google (4), Microsoft (3), Paramount+ (1), Meta (2), Uber (1), Netflix (1), OpenAI (1), X (1), AT&T (1), Comcast (1), Charter (1), Dell (1), FedEx (1), Home Depot (1), Lowe's (1), Marriott (2), UPS (1)

## Auth Flow
Cognito Hosted UI → `callback.html` exchanges code for tokens → stored in `sessionStorage`. Protected API calls include `id_token` in `Authorization` header.
- User Pool: `us-east-1_YRVrviFVa`
- Client ID: `69ldkhrql8sq7652oubmu092kg`
- CloudFront URL: `https://dmmywcvdfo0fv.cloudfront.net`

## Deploy
```bash
# Backend infra
cd terraform && terraform apply

# Frontend
./deploy-frontend.sh   # syncs to S3 + invalidates CloudFront
```

## Key Design Decisions
- One vote per (user_id, button_id) enforced atomically via DynamoDB conditional put
- Leaderboard masks emails: `ab***@domain.com` or falls back to `User #xxxx`
- "Blast Zone" was renamed to "Blast Radius" in the UI
- No build system — everything loads from CDN; just edit HTML and deploy
