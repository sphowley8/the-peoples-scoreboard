// ─── Campaign referral tracking ───────────────────────────────────────────────
// If the page was opened with ?ref=<campaign_id>&name=<campaign_name>, store both.
(function () {
  const params = new URLSearchParams(window.location.search);
  const ref  = params.get("ref");
  const name = params.get("name");
  if (ref)  sessionStorage.setItem("campaign_id",   ref);
  if (name) sessionStorage.setItem("campaign_name", name);
})();

/** Returns the active campaign ID for this session, or "none". */
function getCampaignId() {
  return sessionStorage.getItem("campaign_id") || "none";
}

/** Returns the active campaign name for this session, or null. */
function getCampaignName() {
  return sessionStorage.getItem("campaign_name") || null;
}

/**
 * Returns a stable session ID for anonymous click attribution.
 * Generated once per session and stored in sessionStorage.
 */
function getOrCreateSessionId() {
  let sid = sessionStorage.getItem("session_id");
  if (!sid) {
    sid = crypto.randomUUID();
    sessionStorage.setItem("session_id", sid);
  }
  return sid;
}

// ─── Cognito Config ───────────────────────────────────────────────────────────
const CONFIG = {
  region:      "us-east-1",
  userPoolId:  "us-east-1_YRVrviFVa",   // update after terraform apply
  clientId:    "69ldkhrql8sq7652oubmu092kg", // update after terraform apply
  appBase:     "https://dmmywcvdfo0fv.cloudfront.net",
  // API calls go through CloudFront — cached endpoints are served from the
  // edge; uncached ones pass through to API Gateway transparently.
  apiEndpoint: "https://dmmywcvdfo0fv.cloudfront.net",
};

// ─── Cognito Identity Provider endpoint ──────────────────────────────────────
const COGNITO_IDP = `https://cognito-idp.${CONFIG.region}.amazonaws.com/`;

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

// ─── Logout ───────────────────────────────────────────────────────────────────

function logout() {
  clearTokens();
  window.location.href = `${CONFIG.appBase}/`;
}

// ─── OTP Auth — Step 1: Send code ────────────────────────────────────────────
// Returns: { session, destination }
//   session     — Cognito Session token to pass to respondToOtp()
//   destination — masked address Cognito confirms delivery to (e.g. u***@e***.com)
// Throws an Error with err.code = Cognito __type on failure.

async function initiateOtpAuth(email) {
  const res = await fetch(COGNITO_IDP, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-amz-json-1.1",
      "X-Amz-Target": "AWSCognitoIdentityProviderService.InitiateAuth",
    },
    body: JSON.stringify({
      AuthFlow:       "USER_AUTH",
      ClientId:       CONFIG.clientId,
      AuthParameters: {
        USERNAME:            email,
        PREFERRED_CHALLENGE: "EMAIL_OTP",
      },
    }),
  });

  const data = await res.json();

  if (!res.ok) {
    const err = new Error(data.message || "InitiateAuth failed");
    err.code = data.__type || "";
    throw err;
  }

  // Cognito sends the OTP email and returns EMAIL_OTP directly.
  // Use the session from this response — it matches the code in the email.
  return {
    session:     data.Session,
    destination: data.ChallengeParameters?.CODE_DELIVERY_DESTINATION ?? "",
  };
}

// ─── New user: SignUp only (sends 8-digit verification email) ────────────────
// Returns { session: null, destination: email } — no Cognito session yet.
// The 8-digit code is verified via confirmSignUp(), not RespondToAuthChallenge.

async function signUpNewUser(email) {
  const res = await fetch(COGNITO_IDP, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-amz-json-1.1",
      "X-Amz-Target": "AWSCognitoIdentityProviderService.SignUp",
    },
    body: JSON.stringify({
      ClientId:       CONFIG.clientId,
      Username:       email,
      // SignUp requires a Password field even for EMAIL_OTP pools.
      // This value is never used to sign in.
      Password:       crypto.randomUUID() + "Aa1!",
      UserAttributes: [{ Name: "email", Value: email }],
    }),
  });

  const data = await res.json();

  if (!res.ok) {
    const err = new Error(data.message || "SignUp failed");
    err.code = data.__type || "";
    throw err;
  }

  return {
    session:     null,   // no session — code is confirmed via ConfirmSignUp
    destination: email,
  };
}

// ─── New user: Confirm the 8-digit SignUp code only ──────────────────────────
// Confirms the account. Does NOT initiate a sign-in session.
// After this, the user visits login.html to sign in with a 6-digit OTP.

async function confirmSignUpOnly(email, code) {
  const res = await fetch(COGNITO_IDP, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-amz-json-1.1",
      "X-Amz-Target": "AWSCognitoIdentityProviderService.ConfirmSignUp",
    },
    body: JSON.stringify({
      ClientId:         CONFIG.clientId,
      Username:         email,
      ConfirmationCode: code.trim(),
    }),
  });

  if (!res.ok) {
    const data = await res.json();
    const err  = new Error(data.message || "ConfirmSignUp failed");
    err.code   = data.__type || "";
    throw err;
  }
  // Returns nothing — caller handles redirect to login.html.
}

// ─── OTP Auth — Step 2: Verify code ──────────────────────────────────────────
// Returns Cognito AuthenticationResult: { IdToken, AccessToken, RefreshToken }
// Throws on wrong code, expired session, or network failure.

async function respondToOtp(session, email, code) {
  const res = await fetch(COGNITO_IDP, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-amz-json-1.1",
      "X-Amz-Target": "AWSCognitoIdentityProviderService.RespondToAuthChallenge",
    },
    body: JSON.stringify({
      ChallengeName:      "EMAIL_OTP",
      ClientId:           CONFIG.clientId,
      Session:            session,
      ChallengeResponses: {
        USERNAME:       email,
        EMAIL_OTP_CODE: code.trim(),
      },
    }),
  });

  const data = await res.json();

  if (!res.ok) {
    const err = new Error(data.message || "RespondToAuthChallenge failed");
    err.code = data.__type || "";
    throw err;
  }

  return data.AuthenticationResult;
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
