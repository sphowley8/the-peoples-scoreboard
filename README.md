# the-peoples-scoreboard
This is a web app that will provide users the ability to participate in an organized economic strike that can be measured and visualized effectively.

I am intending for this project to be practice using Claude. It isn't often that you have an idea that excites you and also offers you the ability to learn new skills and use new tools. That is what this is for me.

And if I could make an impact on the world too? Cherry on top.

# Phases
## MVP
1. Create architecture
2. Deploy cloud infrastructure
3. Deploy website such that the following features are satisfied:
   - Users can log in
   - Users can click button to "unsubscribe" and it is tracked in a database and updated at top of screen
   - Users can share the button
4. Create basic utilities such as the following:
   - Spin down AWS infrastructure

---

# Next Steps

## 1. Configure your Terraform variables
```bash
cd the-peoples-scoreboard-terraform/terraform
cp terraform.tfvars.example terraform.tfvars
```
Open `terraform.tfvars` and set:
- `aws_region` — your preferred AWS region
- `environment` — `dev` to start
- `domain_name` — leave blank for now; fill in once you have a domain

## 2. Deploy infrastructure (in this order)

| Step | File | What to verify / update before applying |
|------|------|------------------------------------------|
| 1 | `variables.tf` | Confirm defaults match your preferences |
| 2 | `dynamodb.tf` | No changes needed for MVP |
| 3 | `lambda.tf` + `lambda_src/log_click.py` | No changes needed for MVP |
| 4 | `cognito.tf` | Update `cognito_callback_urls` / `cognito_logout_urls` in `terraform.tfvars` once you know your CloudFront URL |
| 5 | `api_gateway.tf` | No changes needed for MVP |
| 6 | `s3_cloudfront.tf` | Add `domain_name` in `terraform.tfvars` if using a custom domain; leave blank to use the auto-generated CloudFront URL |

Then run:
```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

After apply, `terraform output` will print your CloudFront URL, API endpoint, and Cognito IDs — you'll need these for the frontend.

## 3. Update Cognito callback URLs
Once you have your CloudFront URL from `terraform output cloudfront_domain`, add it to `terraform.tfvars`:
```hcl
cognito_callback_urls = [
  "http://localhost:3000/callback",
  "https://<your-cloudfront-domain>/callback",
]
cognito_logout_urls = [
  "http://localhost:3000",
  "https://<your-cloudfront-domain>",
]
```
Then re-run `terraform apply`.

## 4. Build and deploy the frontend
- Build a static site (plain HTML/JS or a framework like React/Vue)
- Wire up the Cognito Hosted UI for login using the `cognito_client_id` and `cognito_hosted_ui_url` outputs
- On button click, call `POST /log-click` with the user's JWT in the `Authorization` header
- Deploy to S3: `aws s3 sync ./dist s3://<your-bucket-name> --delete`
- Invalidate the CloudFront cache: `aws cloudfront create-invalidation --distribution-id <id> --paths "/*"`

## 5. Tear down when done
```bash
./scripts/teardown.sh
```
