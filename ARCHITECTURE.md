<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>AWS App Architecture</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600;700&family=Syne:wght@400;700;800&display=swap');

  :root {
    --aws-orange: #FF9900;
    --aws-dark: #232F3E;
    --aws-blue: #1A73E8;
    --accent-teal: #00C9A7;
    --accent-purple: #7C5CBF;
    --bg: #0d1117;
    --surface: #161b22;
    --border: #30363d;
    --text: #e6edf3;
    --muted: #8b949e;
  }

  * { box-sizing: border-box; margin: 0; padding: 0; }

  body {
    background: var(--bg);
    color: var(--text);
    font-family: 'Syne', sans-serif;
    min-height: 100vh;
    padding: 40px 24px;
    overflow-x: hidden;
  }

  h1 {
    font-size: clamp(1.4rem, 3vw, 2.2rem);
    font-weight: 800;
    letter-spacing: -0.03em;
    color: var(--aws-orange);
    text-align: center;
    margin-bottom: 6px;
  }

  .subtitle {
    text-align: center;
    color: var(--muted);
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.8rem;
    margin-bottom: 48px;
    letter-spacing: 0.05em;
  }

  .diagram {
    max-width: 900px;
    margin: 0 auto;
    display: flex;
    flex-direction: column;
    gap: 0;
  }

  /* LAYERS */
  .layer {
    display: flex;
    align-items: stretch;
    gap: 16px;
    margin-bottom: 0;
    position: relative;
  }

  .layer-label {
    writing-mode: vertical-rl;
    text-orientation: mixed;
    transform: rotate(180deg);
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.65rem;
    font-weight: 600;
    letter-spacing: 0.12em;
    color: var(--muted);
    text-transform: uppercase;
    min-width: 28px;
    display: flex;
    align-items: center;
    justify-content: center;
    opacity: 0.7;
  }

  .layer-content {
    flex: 1;
    display: flex;
    gap: 12px;
    padding: 20px 20px;
    border-radius: 12px;
    border: 1px solid var(--border);
    background: var(--surface);
    align-items: center;
  }

  .layer-content.user-layer { border-color: #58a6ff44; background: #161b2299; }
  .layer-content.frontend-layer { border-color: var(--aws-orange)44; background: #1c1a1399; }
  .layer-content.auth-layer { border-color: var(--accent-teal)44; background: #101c1a99; }
  .layer-content.api-layer { border-color: var(--accent-purple)44; background: #16121c99; }
  .layer-content.db-layer { border-color: #ff6b6b44; background: #1c111199; }

  /* ARROWS between layers */
  .arrow-row {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 36px;
    position: relative;
  }

  .arrow-row::after {
    content: '';
    position: absolute;
    left: 50%;
    top: 0;
    bottom: 0;
    width: 2px;
    background: linear-gradient(to bottom, var(--border), var(--muted));
    opacity: 0.4;
  }

  .arrow-label {
    background: var(--bg);
    padding: 2px 10px;
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.65rem;
    color: var(--muted);
    border: 1px solid var(--border);
    border-radius: 20px;
    z-index: 1;
    position: relative;
    white-space: nowrap;
  }

  /* SERVICE CARDS */
  .service {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
    padding: 14px 16px;
    border-radius: 10px;
    background: var(--bg);
    border: 1px solid var(--border);
    min-width: 120px;
    flex: 1;
    cursor: default;
    transition: transform 0.18s ease, box-shadow 0.18s ease, border-color 0.18s ease;
    animation: fadeUp 0.5s ease both;
  }

  .service:hover {
    transform: translateY(-3px);
    box-shadow: 0 8px 24px #00000066;
  }

  .service.s3:hover { border-color: var(--aws-orange); box-shadow: 0 8px 24px #FF990022; }
  .service.cloudfront:hover { border-color: var(--aws-orange); box-shadow: 0 8px 24px #FF990022; }
  .service.cognito:hover { border-color: var(--accent-teal); box-shadow: 0 8px 24px #00C9A722; }
  .service.apigw:hover { border-color: var(--accent-purple); box-shadow: 0 8px 24px #7C5CBF22; }
  .service.lambda:hover { border-color: var(--accent-purple); box-shadow: 0 8px 24px #7C5CBF22; }
  .service.dynamo:hover { border-color: #ff6b6b; box-shadow: 0 8px 24px #ff6b6b22; }

  .service-icon {
    font-size: 1.8rem;
    line-height: 1;
  }

  .service-name {
    font-weight: 700;
    font-size: 0.8rem;
    color: var(--text);
    text-align: center;
    letter-spacing: -0.01em;
  }

  .service-detail {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.65rem;
    color: var(--muted);
    text-align: center;
    line-height: 1.5;
  }

  .service-badge {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.58rem;
    padding: 2px 7px;
    border-radius: 20px;
    font-weight: 600;
    letter-spacing: 0.04em;
    text-transform: uppercase;
  }

  .badge-orange { background: #FF990022; color: var(--aws-orange); border: 1px solid #FF990044; }
  .badge-teal { background: #00C9A722; color: var(--accent-teal); border: 1px solid #00C9A744; }
  .badge-purple { background: #7C5CBF22; color: #a78bfa; border: 1px solid #7C5CBF44; }
  .badge-red { background: #ff6b6b22; color: #ff8080; border: 1px solid #ff6b6b44; }

  /* USER block */
  .user-block {
    display: flex;
    align-items: center;
    gap: 16px;
    flex: 1;
  }

  .user-icon-box {
    font-size: 2.4rem;
  }

  .user-desc h3 { font-size: 0.9rem; font-weight: 700; margin-bottom: 4px; }
  .user-desc p {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.68rem;
    color: var(--muted);
    line-height: 1.6;
  }

  /* FLOW LEGEND */
  .legend {
    max-width: 900px;
    margin: 32px auto 0;
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 12px;
  }

  .legend-item {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 14px 16px;
    animation: fadeUp 0.5s ease both;
  }

  .legend-item h4 {
    font-size: 0.78rem;
    font-weight: 700;
    margin-bottom: 6px;
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .legend-item p {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.65rem;
    color: var(--muted);
    line-height: 1.6;
  }

  .dot {
    width: 8px; height: 8px; border-radius: 50%; display: inline-block; flex-shrink: 0;
  }

  @keyframes fadeUp {
    from { opacity: 0; transform: translateY(16px); }
    to { opacity: 1; transform: translateY(0); }
  }

  .service { animation-delay: calc(var(--i, 0) * 0.07s); }

  .phase-tag {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.6rem;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: var(--aws-orange);
    font-weight: 600;
    text-align: center;
    margin-bottom: 12px;
  }

  .connector { color: var(--muted); font-size: 1rem; flex-shrink: 0; align-self: center; }
</style>
</head>
<body>

<h1>Your AWS Web App — Architecture</h1>
<p class="subtitle">// phase 1 blueprint · serverless · scalable · pay-as-you-go</p>

<div class="diagram">

  <!-- USER -->
  <div class="layer">
    <div class="layer-label">Client</div>
    <div class="layer-content user-layer">
      <div class="user-block">
        <div class="user-icon-box">🧑‍💻</div>
        <div class="user-desc">
          <h3>User / Browser</h3>
          <p>Signs in → sees buttons → clicks → gets redirected<br>Every click is silently logged in the background</p>
        </div>
      </div>
    </div>
  </div>

  <div class="arrow-row"><span class="arrow-label">HTTPS requests</span></div>

  <!-- FRONTEND -->
  <div class="layer">
    <div class="layer-label">Hosting</div>
    <div class="layer-content frontend-layer">
      <div class="service s3" style="--i:1">
        <span class="service-icon">🪣</span>
        <span class="service-name">S3 Bucket</span>
        <span class="service-detail">Stores your HTML,<br>CSS & JS files</span>
        <span class="service-badge badge-orange">Static Hosting</span>
      </div>
      <div class="connector">→</div>
      <div class="service cloudfront" style="--i:2">
        <span class="service-icon">🌐</span>
        <span class="service-name">CloudFront</span>
        <span class="service-detail">Global CDN,<br>HTTPS, fast delivery</span>
        <span class="service-badge badge-orange">CDN + SSL</span>
      </div>
    </div>
  </div>

  <div class="arrow-row"><span class="arrow-label">Sign-in / token</span></div>

  <!-- AUTH -->
  <div class="layer">
    <div class="layer-label">Auth</div>
    <div class="layer-content auth-layer">
      <div class="service cognito" style="--i:3">
        <span class="service-icon">🔐</span>
        <span class="service-name">Amazon Cognito</span>
        <span class="service-detail">User sign-up, sign-in<br>& session tokens (JWT)<br>Persona management</span>
        <span class="service-badge badge-teal">Identity</span>
      </div>
    </div>
  </div>

  <div class="arrow-row"><span class="arrow-label">Authenticated API call on button click</span></div>

  <!-- API + LAMBDA -->
  <div class="layer">
    <div class="layer-label">Backend</div>
    <div class="layer-content api-layer">
      <div class="service apigw" style="--i:4">
        <span class="service-icon">🚪</span>
        <span class="service-name">API Gateway</span>
        <span class="service-detail">REST endpoint<br>POST /log-click<br>Validates JWT token</span>
        <span class="service-badge badge-purple">Gateway</span>
      </div>
      <div class="connector">→</div>
      <div class="service lambda" style="--i:5">
        <span class="service-icon">λ</span>
        <span class="service-name">Lambda Function</span>
        <span class="service-detail">Receives click event<br>Writes to DynamoDB<br>Returns 200 OK</span>
        <span class="service-badge badge-purple">Serverless</span>
      </div>
    </div>
  </div>

  <div class="arrow-row"><span class="arrow-label">Write click log</span></div>

  <!-- DATABASE -->
  <div class="layer">
    <div class="layer-label">Data</div>
    <div class="layer-content db-layer">
      <div class="service dynamo" style="--i:6">
        <span class="service-icon">🗄️</span>
        <span class="service-name">DynamoDB</span>
        <span class="service-detail">Stores: user_id, button_id,<br>timestamp, target_url<br>Serverless NoSQL</span>
        <span class="service-badge badge-red">Database</span>
      </div>
    </div>
  </div>

</div>

<!-- LEGEND -->
<div class="legend">
  <div class="legend-item" style="--i:7">
    <h4><span class="dot" style="background:var(--aws-orange)"></span> Step 1 — Hosting</h4>
    <p>Upload your site to S3. CloudFront serves it to users worldwide over HTTPS with low latency. Free SSL cert included.</p>
  </div>
  <div class="legend-item" style="--i:8">
    <h4><span class="dot" style="background:var(--accent-teal)"></span> Step 2 — Auth</h4>
    <p>Cognito handles sign-up & sign-in. After login, users get a JWT token stored in the browser. No server needed.</p>
  </div>
  <div class="legend-item" style="--i:9">
    <h4><span class="dot" style="background:#a78bfa)"></span> Step 3 — Click Logging</h4>
    <p>On button click: JS fires a POST to API Gateway → Lambda writes a row to DynamoDB. Then the redirect happens.</p>
  </div>
  <div class="legend-item" style="--i:10">
    <h4><span class="dot" style="background:#ff8080"></span> Step 4 — Data</h4>
    <p>Each DynamoDB row: user_id + button_id + timestamp + URL. Query by user or by button anytime.</p>
  </div>
</div>

</body>
</html>
