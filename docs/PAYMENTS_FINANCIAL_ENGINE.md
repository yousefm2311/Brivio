# Phase 8 & 8.5 Subscriptions, Invoices & Financial Engine Specification

## 1. Non-Negotiable Financial Security Principle
Client applications (Flutter) are strictly prohibited from mutating invoice or payment statuses (`status = 'paid'`). Authoritative settlement occurs exclusively through server-verified provider API calls, cryptographically signed webhooks, or authorized manual cash collection RPCs.

## 2. Money Representation & Currency
- **Monetary Unit:** Integer minor units (`BIGINT`) representing Egyptian piastres (e.g., EGP 1250.75 $\to$ 125075 minor units). Binary floating point (`double`/`float`) is prohibited for financial calculation.
- **Currency:** Explicit ISO 4217 currency code (default `'EGP'`).

## 3. Provider Integration & Webhook Verification
### Paymob Adapter
- **API Model:** Hosted Checkout / Payment Intents API.
- **HMAC Verification:** Server webhook verifies Paymob HMAC SHA-512 signature against `PAYMOB_HMAC_SECRET`. Missing or invalid signatures trigger HTTP 401/400 quarantine responses without database mutation.

### Fawry Adapter
- **API Model:** Merchant Server-to-Server Notification API.
- **Signature Algorithm:** SHA-256 concatenation: `HEX(SHA256(merchantCode + merchantRefNum + paymentAmount + secretKey))`.

## 4. Edge Functions Architecture
- `create-payment-intent`: Server endpoint verifying JWT & ownership, loading invoice server-side, and calculating authoritative balance.
- `payment-webhook-paymob`: Server webhook verifying Paymob HMAC signature before executing `apply_verified_payment`.
- `payment-webhook-fawry`: Server webhook verifying Fawry SHA-256 signature before executing `apply_verified_payment`.
- `reconcile-payment`: Authenticated staff/admin endpoint for idempotent status polling and manual reconciliation.

## 5. Security & RPC Privilege Denial
- `apply_verified_payment`: `EXECUTE` privilege is strictly **REVOKED** from `PUBLIC` and `authenticated`. ONLY `service_role` can invoke settlement.
- `payment_provider_events`: Audit log table for un-sensitive webhook metadata.

## 6. Quality Gate Execution
- **Database (pgTAP):** 73 / 73 passing assertions on live PostgreSQL stack.
- **Flutter Quality Gate:** 48 / 48 passing unit and widget tests with 0 analyzer issues.
