import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { computePaymobHmac } from "../_shared/payments/paymob_adapter.ts";
import { crypto } from "https://deno.land/std@0.168.0/crypto/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

async function hashPayload(payload: unknown): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(JSON.stringify(payload));
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hashBuffer)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const paymobHmacSecret = Deno.env.get("PAYMOB_HMAC_SECRET") ?? "test_paymob_secret";
  const adminClient = createClient(supabaseUrl, supabaseServiceKey);

  let payload: Record<string, unknown> = {};

  try {
    payload = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── 1. HMAC presence check
  const hmacHeader = req.headers.get("hmac") || req.headers.get("x-paymob-hmac");
  if (!hmacHeader) {
    await recordAudit(adminClient, "paymob", null, null, payload, "missing_hmac", "received", "HMAC header absent");
    return new Response(JSON.stringify({ error: "Missing HMAC signature" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const obj = (payload.obj as Record<string, unknown>) || payload;

  // ── 2. HMAC cryptographic verification (ALWAYS — no environment bypass)
  const computedHmac = await computePaymobHmac(obj as Record<string, unknown>, paymobHmacSecret);
  if (computedHmac.toLowerCase() !== hmacHeader.toLowerCase()) {
    await recordAudit(adminClient, "paymob", null, String(obj.id ?? ""), payload, "invalid_hmac", "rejected", "HMAC mismatch");
    return new Response(JSON.stringify({ error: "Invalid HMAC signature" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── 3. Extract fields
  const attemptId   = String((obj.order as Record<string,unknown>)?.merchant_order_id ?? obj.merchant_order_id ?? "");
  const providerTxId = String(obj.id ?? obj.transaction_id ?? "");
  const success      = obj.success === true || obj.success === "true";
  const amountMinor  = Number(obj.amount_cents ?? obj.amount ?? 0);
  const currency     = String(obj.currency ?? "EGP");

  // ── 4. Non-success → acknowledge without settlement
  if (!success) {
    await recordAudit(adminClient, "paymob", providerTxId, attemptId, payload, "non_success_callback", "processed", null);
    return new Response(
      JSON.stringify({ message: "Non-success callback acknowledged", status: "acknowledged", transaction_status: "not_paid" }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  // ── 5. Resolve payment attempt to verify authoritative amount
  if (!attemptId) {
    await recordAudit(adminClient, "paymob", providerTxId, null, payload, "unknown_reference", "quarantined", "No attempt reference");
    return new Response(JSON.stringify({ error: "Unknown payment attempt reference" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { data: attempt, error: attErr } = await adminClient
    .from("payment_attempts")
    .select("id, amount_minor, currency, status, invoice_id")
    .eq("id", attemptId)
    .maybeSingle();

  if (attErr || !attempt) {
    await recordAudit(adminClient, "paymob", providerTxId, attemptId, payload, "unknown_reference", "quarantined", "Attempt not found");
    return new Response(JSON.stringify({ error: "Payment attempt not found" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── 6. Amount financial validation (valid HMAC but wrong amount → quarantine)
  if (amountMinor !== attempt.amount_minor) {
    await recordAudit(adminClient, "paymob", providerTxId, attemptId, payload, "amount_mismatch", "quarantined",
      `Provider amount ${amountMinor} ≠ attempt amount ${attempt.amount_minor}`);
    return new Response(
      JSON.stringify({ error: "Amount mismatch: provider amount does not match authoritative payment attempt amount" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  // ── 7. Currency validation
  if (currency.toUpperCase() !== attempt.currency.toUpperCase()) {
    await recordAudit(adminClient, "paymob", providerTxId, attemptId, payload, "currency_mismatch", "quarantined",
      `Provider currency ${currency} ≠ attempt currency ${attempt.currency}`);
    return new Response(
      JSON.stringify({ error: "Currency mismatch" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  // ── 8. Apply verified settlement (service_role boundary)
  const { data: result, error: settleErr } = await adminClient.rpc("apply_verified_payment", {
    p_attempt_id:      attemptId,
    p_provider_tx_id:  providerTxId,
    p_amount_minor:    amountMinor,
    p_currency:        currency,
  });

  if (settleErr) {
    await recordAudit(adminClient, "paymob", providerTxId, attemptId, payload, "settlement_error", "quarantined", settleErr.message);
    return new Response(JSON.stringify({ error: settleErr.message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  await recordAudit(adminClient, "paymob", providerTxId, attemptId, payload, "payment_settled", "processed", null);

  return new Response(JSON.stringify(result), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});

async function recordAudit(
  client: ReturnType<typeof createClient>,
  provider: string,
  providerEventId: string | null,
  txRef: string | null,
  payload: unknown,
  eventType: string,
  status: string,
  errorCode: string | null,
) {
  try {
    const payloadHash = await hashPayload(payload);
    await client.from("payment_provider_events").insert({
      provider,
      provider_event_id: providerEventId,
      transaction_reference: txRef,
      event_type: eventType,
      payload_hash: payloadHash,
      status,
      error_code: errorCode,
      processed_at: status !== "received" ? new Date().toISOString() : null,
    });
  } catch {
    // Audit failures must never block the main flow
  }
}
