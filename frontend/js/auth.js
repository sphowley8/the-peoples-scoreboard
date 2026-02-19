// ─── Cognito Config ───────────────────────────────────────────────────────────
const CONFIG = {
  region:       "us-east-1",
  userPoolId:   "us-east-1_YRVrviFVa",
  clientId:     "69ldkhrql8sq7652oubmu092kg",
  hostedUiBase: "https://peoples-scoreboard-dev.auth.us-east-1.amazoncognito.com",
  appBase:      "https://dmmywcvdfo0fv.cloudfront.net",
  apiEndpoint:  "https://zhl7evbf4i.execute-api.us-east-1.amazonaws.com/dev",
};

// ─── Token Helpers ────────────────────────────────────────────────────────────

function saveTokens({ id_token, access_token, refresh_token }) {
  if (id_token)      sessionStorage.setItem("id_token", id_token);
  if (access_token)  sessionStorage.setItem("access_token", access_token);
  if (refresh_token) sessionStorage.setItem("refresh_token", refresh_token);
}

function getIdToken()     { return sessionStorage.getItem("id_token"); }
function getAccessToken() { return sessionStorage.getItem("access_token"); }

function clearTokens() {
  sessionStorage.removeItem("id_token");
  sessionStorage.removeItem("access_token");
  sessionStorage.removeItem("refresh_token");
}

// ─── JWT Decode (no library needed) ──────────────────────────────────────────

function parseJwt(token) {
  try {
    const base64 = token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(atob(base64));
  } catch {
    return null;
  }
}

function isTokenExpired(token) {
  const payload = parseJwt(token);
  if (!payload) return true;
  return Date.now() / 1000 > payload.exp;
}

// ─── Auth State ───────────────────────────────────────────────────────────────

function isLoggedIn() {
  const token = getIdToken();
  return token && !isTokenExpired(token);
}

function getCurrentUser() {
  const token = getIdToken();
  if (!token) return null;
  return parseJwt(token);
}

// ─── Cognito Hosted UI URLs ───────────────────────────────────────────────────

function getLoginUrl() {
  const params = new URLSearchParams({
    client_id:     CONFIG.clientId,
    response_type: "code",
    scope:         "openid email profile",
    redirect_uri:  `${CONFIG.appBase}/callback.html`,
  });
  return `${CONFIG.hostedUiBase}/login?${params}`;
}

function getSignUpUrl() {
  const params = new URLSearchParams({
    client_id:     CONFIG.clientId,
    response_type: "code",
    scope:         "openid email profile",
    redirect_uri:  `${CONFIG.appBase}/callback.html`,
  });
  return `${CONFIG.hostedUiBase}/signup?${params}`;
}

function getLogoutUrl() {
  const params = new URLSearchParams({
    client_id:  CONFIG.clientId,
    logout_uri: CONFIG.appBase,
  });
  return `${CONFIG.hostedUiBase}/logout?${params}`;
}

// ─── Exchange Auth Code for Tokens ───────────────────────────────────────────

async function exchangeCodeForTokens(code) {
  const body = new URLSearchParams({
    grant_type:   "authorization_code",
    client_id:    CONFIG.clientId,
    code,
    redirect_uri: `${CONFIG.appBase}/callback.html`,
  });

  const res = await fetch(`${CONFIG.hostedUiBase}/oauth2/token`, {
    method:  "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });

  if (!res.ok) throw new Error("Token exchange failed");
  return res.json();
}

// ─── Logout ───────────────────────────────────────────────────────────────────

function logout() {
  clearTokens();
  window.location.href = getLogoutUrl();
}

// ─── API Helper ───────────────────────────────────────────────────────────────

async function apiPost(path, payload) {
  const token = getIdToken();
  if (!token) throw new Error("Not authenticated");

  const res = await fetch(`${CONFIG.apiEndpoint}${path}`, {
    method:  "POST",
    headers: {
      "Content-Type":  "application/json",
      "Authorization": token,
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}
