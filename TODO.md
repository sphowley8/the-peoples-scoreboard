# The People's Scoreboard — TODO

## Testing

### Unit Testing
- [ ] Create automated unit tests to verify site correctness end-to-end
  - [ ] Every tracked link click successfully increments the campaign total
  - [ ] Every tracked link click successfully increments the overall (all campaigns) total
  - [ ] Campaign totals and overall total match the values stored in DynamoDB (click-log and click-dedup tables)
  - [ ] Dedup logic is enforced: a second click from the same user on the same button does not increment counts
  - [ ] Unauthenticated users with a campaign `?ref=` link correctly log to the campaign without a user record

### Unit Testing — Market Cap Utility Functions (`js/marketcap.js`)
- [ ] Add unit tests to validate that subscription prices are accurate and up to date
  - [ ] `getMonthlyPrice(buttonId)` returns the correct known price for every button ID in `MONTHLY_PRICES`
  - [ ] `getMonthlyPrice('unknown-id')` returns `0` (safe fallback)
  - [ ] Prices are periodically reviewed and updated to match current retail rates (quarterly review recommended)
- [ ] Add unit tests to validate that market cap calculations are correct end-to-end
  - [ ] `calcMarketCapImpact('amazon-prime', 1)` === `14.99 × 12 × 10` === `1,798.80`
  - [ ] `calcMarketCapImpact('netflix', 1)` === `15.49 × 12 × 10` === `1,858.80`
  - [ ] `calcMarketCapImpact('whatsapp', 100)` === `0` (free service, no revenue impact)
  - [ ] `calcMarketCapImpact(id, 0)` === `0` for all button IDs (zero clicks = zero impact)
  - [ ] `calcTotalMarketCapImpact({})` === `0` (empty input)
  - [ ] `calcTotalMarketCapImpact({ 'amazon-prime': 1, 'netflix': 1 })` === sum of individual impacts
  - [ ] Hero counter displayed value matches `calcTotalMarketCapImpact` computed from live DB click counts

---

## Observability & Monitoring

### Daily Site Traffic Monitoring (Internal)
- [ ] Build a daily traffic monitoring pipeline for internal visibility
  - [ ] Log: unique users visited per day
  - [ ] Log: total unsubscribes per day (overall)
  - [ ] Log: unsubscribes per campaign per day
  - [ ] Log: unsubscribes per company/button being boycotted per day
  - [ ] Store logs in a durable, queryable format (e.g. S3 + Athena, or DynamoDB with TTL)
  - [ ] Consider a simple internal dashboard (e.g. CloudWatch or a private read-only page)

---

## Performance & Scalability

### 1M Users / Day Capacity
- [ ] Load test the current stack to establish baseline throughput limits
- [ ] Review API Gateway + Lambda concurrency limits; raise reserved concurrency as needed
- [ ] Review DynamoDB read/write capacity; switch to on-demand billing mode if not already set
- [ ] Confirm CloudFront caching is aggressively caching `/click-count*` and `/leaderboard*` to reduce Lambda cold-path hits
- [ ] Evaluate Lambda cold start latency under burst traffic; consider provisioned concurrency for hot endpoints
- [ ] Review S3 + CloudFront static asset delivery — should be effectively unlimited, but confirm cache-control headers are set
- [ ] Add WAF (AWS WAF) in front of CloudFront to protect against bot floods and abuse at scale
- [ ] Set up CloudWatch alarms for Lambda throttles, DynamoDB throttles, and API Gateway 5xx rates

---

## Infrastructure Lifecycle

### Teardown & Backup Process
- [ ] Write a `backup.sh` (or Terraform/Lambda equivalent) that:
  - [ ] Exports all DynamoDB tables to S3 (use DynamoDB export-to-S3 feature or `aws dynamodb export-table-to-point-in-time`)
    - [ ] `peoples-scoreboard-click-log-dev`
    - [ ] `peoples-scoreboard-click-dedup-dev`
  - [ ] Exports Cognito user pool data (use `cognito-idp list-users` + store to S3)
  - [ ] Tags the backup with a timestamp and environment label
- [ ] Write a `teardown.sh` that:
  - [ ] Confirms backup is complete before proceeding
  - [ ] Runs `terraform destroy` (or scales resources to zero where destroy isn't appropriate)
  - [ ] Leaves S3 backup bucket intact (excluded from destroy)
- [ ] Write a `restore.sh` / re-provision runbook that:
  - [ ] Runs `terraform apply` to recreate infrastructure
  - [ ] Imports DynamoDB backups from S3
  - [ ] Re-imports or recreates Cognito users from backup
  - [ ] Verifies site health post-restore
- [ ] Document the full spin-down / spin-up process in the repo README
- [ ] Test the full cycle in a staging environment before relying on it in production
