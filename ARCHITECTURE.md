# AWS Web App — Architecture Blueprint
> Phase 1 · Serverless · Scalable · Pay-as-you-go

---

## System Overview

```
🧑‍💻 User / Browser
        │
        │  HTTPS requests
        ▼
🌐 CloudFront (CDN + SSL)
        │
        ▼
🪣 S3 Bucket (Static site hosting)
        │
        │  Sign-in / token
        ▼
🔐 Amazon Cognito (Auth & identity)
        │
        │  Authenticated API call on button click
        ▼
🚪 API Gateway  ──→  λ Lambda Function
                              │
                              │  Write click log
                              ▼
                      🗄️ DynamoDB (Database)
```

---

## Layer Breakdown

### 1. 🪣 S3 + 🌐 CloudFront — Hosting
- **S3** stores your static website files (HTML, CSS, JS)
- **CloudFront** is AWS's global CDN — serves your site worldwide over HTTPS with low latency
- Free SSL certificate included via AWS Certificate Manager

### 2. 🔐 Amazon Cognito — Authentication
- Manages user sign-up, sign-in, and password resets
- After login, each user receives a **JWT (JSON Web Token)** stored in the browser
- This token acts as the user's secure identity badge for all subsequent requests
- No auth server to manage — fully serverless

### 3. 🚪 API Gateway + λ Lambda — Backend
- On button click, the browser fires a `POST /log-click` request to **API Gateway**
- API Gateway validates the user's JWT token, then triggers **Lambda**
- Lambda is a small serverless function that runs on demand (no server to manage)
- Lambda writes the click event to DynamoDB, then returns `200 OK`
- The browser then performs the redirect to the button's target URL

### 4. 🗄️ DynamoDB — Database
- Serverless NoSQL database — no provisioning required
- Each row stores:

| Field        | Description                        |
|--------------|------------------------------------|
| `user_id`    | Who clicked (from Cognito token)   |
| `button_id`  | Which button was clicked           |
| `timestamp`  | When it happened (Unix or ISO)     |
| `target_url` | Where the button redirected to     |

---

## Build Order

| Step | Task                                      |
|------|-------------------------------------------|
| 1    | Set up AWS account & IAM permissions      |
| 2    | Create the DynamoDB table                 |
| 3    | Write & deploy the Lambda function        |
| 4    | Hook up API Gateway                       |
| 5    | Set up Cognito user pool                  |
| 6    | Build the frontend (buttons + auth UI)    |
| 7    | Deploy to S3 + CloudFront                 |

---

## Key Design Decisions

- **Fully serverless** — No EC2 instances, no servers to patch or maintain
- **Pay-as-you-go** — You only pay for actual usage (clicks, logins, requests)
- **JWT-based auth** — Cognito tokens mean the backend always knows *who* clicked
- **Decoupled logging** — The click log happens in the background; the redirect is instant for the user
