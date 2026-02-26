// ─── Market Cap Impact Utilities ─────────────────────────────────────────────
//
// Formula: clicks × monthly_price × 12 × 10
//   - monthly_price  : current retail monthly subscription price for that service
//   - × 12           : annualise the subscription revenue
//   - × 10           : apply a 10× revenue multiple (conservative SaaS/tech market cap multiplier)
//
// Prices are hardcoded at the standard single-user monthly rate (USD).
// Services with no recurring subscription (boycotts, one-time purchases) use
// a flat $0 price — they still register as clicks in the DB but contribute $0
// to the market cap estimate until a meaningful LTV proxy is defined.
// ─────────────────────────────────────────────────────────────────────────────

const MONTHLY_PRICES = {
  // ── Amazon ────────────────────────────────────────────────────────────────
  "amazon-prime":      14.99,   // Prime individual monthly
  "audible":           7.95,    // Audible Plus (entry tier)
  "amazon-music":      9.99,    // Amazon Music Unlimited individual
  "prime-video":       8.99,    // Prime Video standalone
  "amazon-grocery":    9.99,    // Amazon Fresh / Grocery add-on
  "kindle-unlimited":  11.99,   // Kindle Unlimited

  // ── Apple ─────────────────────────────────────────────────────────────────
  "apple-music":       10.99,   // Apple Music individual
  "apple-news":        12.99,   // Apple News+
  "apple-tv":          9.99,    // Apple TV+
  "apple-one":         19.95,   // Apple One individual (bundles Music, TV+, Arcade, iCloud+)
  "apple-fitness":     9.99,    // Apple Fitness+
  "apple-arcade":      6.99,    // Apple Arcade

  // ── Google ────────────────────────────────────────────────────────────────
  "youtube-premium":   13.99,   // YouTube Premium individual
  "youtube-music":     10.99,   // YouTube Music Premium individual
  "youtube-tv":        72.99,   // YouTube TV
  "google-one":        2.99,    // Google One 100 GB (entry tier)

  // ── Microsoft ─────────────────────────────────────────────────────────────
  "microsoft-office":  9.99,    // Microsoft 365 Personal monthly
  "xbox-gamepass":     14.99,   // Xbox Game Pass Ultimate monthly
  "linkedin-premium":  39.99,   // LinkedIn Premium Career monthly

  // ── Paramount+ ────────────────────────────────────────────────────────────
  "paramount-plus":    7.99,    // Paramount+ Essential (with ads)

  // ── Meta ──────────────────────────────────────────────────────────────────
  // WhatsApp and Facebook are free services; boycott = delete account.
  // No recurring subscription price — no direct market cap revenue contribution.
  "whatsapp":          0,
  "facebook":          0,

  // ── Uber ──────────────────────────────────────────────────────────────────
  "uber-one":          9.99,    // Uber One monthly

  // ── Netflix ───────────────────────────────────────────────────────────────
  "netflix":           15.49,   // Netflix Standard monthly

  // ── OpenAI ────────────────────────────────────────────────────────────────
  "chatgpt-plus":      20.00,   // ChatGPT Plus monthly

  // ── X (Twitter) ───────────────────────────────────────────────────────────
  "x-premium":         8.00,    // X Premium monthly (basic tier)

  // ── Blast Radius — ICE contractors ───────────────────────────────────────
  // These are not subscription services. Using $0 until a meaningful
  // per-customer LTV proxy is established.
  "att-wireless":      0,
  "comcast":           0,
  "charter":           0,
  "dell":              0,
  "fedex":             0,
  "home-depot":        0,
  "lowes":             0,
  "marriott":          0,
  "marriott-bonvoy":   0,
  "ups":               0,
};

/**
 * Returns the monthly subscription price (USD) for a given button ID.
 * Falls back to 0 for any unknown button ID.
 *
 * @param {string} buttonId - The tracked button ID (e.g. "amazon-prime")
 * @returns {number} Monthly price in USD
 */
function getMonthlyPrice(buttonId) {
  return MONTHLY_PRICES[buttonId] ?? 0;
}

/**
 * Calculates the estimated market cap impact for a number of clicks on a
 * single button/service.
 *
 * Formula: clicks × monthly_price × 12 × 10
 *
 * @param {string} buttonId - The tracked button ID
 * @param {number} clicks   - Number of logged unsubscribe clicks
 * @returns {number} Estimated market cap impact in USD
 */
function calcMarketCapImpact(buttonId, clicks) {
  const monthly = getMonthlyPrice(buttonId);
  return clicks * monthly * 12 * 10;
}

/**
 * Given a map of { buttonId: clickCount }, returns the total estimated
 * market cap impact across all buttons.
 *
 * @param {Object.<string, number>} clicksByButton - e.g. { "amazon-prime": 42, "netflix": 7 }
 * @returns {number} Total market cap impact in USD
 */
function calcTotalMarketCapImpact(clicksByButton) {
  return Object.entries(clicksByButton).reduce((sum, [id, count]) => {
    return sum + calcMarketCapImpact(id, count);
  }, 0);
}

/**
 * Formats a dollar amount as a compact string with $ prefix and comma separators.
 * Retains cents — use this for precise internal calculations and display where
 * full precision is needed.
 * e.g. 1234567.89 → "$1,234,567.89"
 *
 * @param {number} amount
 * @returns {string}
 */
function formatMarketCap(amount) {
  return '$' + amount.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

/**
 * Formats a dollar amount rounded to the nearest whole number.
 * Use this for hero counter display where cents add visual noise.
 * Calculation is NOT rounded — only the display string is.
 * e.g. 1234567.89 → "$1,234,568"
 *
 * @param {number} amount
 * @returns {string}
 */
function formatMarketCapRounded(amount) {
  return '$' + Math.round(amount).toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 0 });
}

/**
 * Formats a monthly price for inline display next to a subscription label.
 * Returns an empty string for $0 services (free / non-subscription).
 * e.g. 14.99 → "$14.99/mo"  |  0 → ""
 *
 * @param {string} buttonId
 * @returns {string}
 */
function formatMonthlyPriceLabel(buttonId) {
  const price = getMonthlyPrice(buttonId);
  if (price === 0) return '';
  return '$' + price.toFixed(2) + '/mo';
}
