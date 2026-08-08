import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { verifyFawryNotificationSignature, buildFawryChargeSignature } from "../_shared/payments/fawry_adapter.ts";
import { minorUnitsToDecimalString } from "../_shared/payments/money_converter.ts";
import { crypto } from "https://deno.land/std@0.168.0/crypto/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Fawry statuses that should be acknowledged (200) without settlement
const FAWRY_ACK_STATUSES = new Set(["NEW", "FAILED", "CANCELED", "EXPIRED", "REFUNDED"]);

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

  const supabaseUrl      = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const fawrySecretKey   = Deno.env.get("FAWRY_SECURITY_KEY") ?? "test_fawry_secret";
  const adminClient      = createClient(supabaseUrl, supabaseServiceKey);

  let payload: Record<string, unknown> = {};
  try {
    payload = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const {
    fawryRefNumber,
    merchantRefNum,
    paymentAmount,
    orderAmount,
    orderStatus,
    paymentMethod,
    paymentReferenceNumber,
    messageSignature,
    signature,
  } = payload as Record<string, string | undefined>;

  const sigToVerify = messageSignature ?? signature;

  // ── 1. Signature presence check
  if (!sigToVerify) {
    await recordAudit(adminClient, "fawry", null, null, payload, "missing_signature", "received", "Signature field absent");
    return new Response(JSON.stringify({ error: "Missing Fawry notification signature" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── 2. merchantRefNum presence check
  if (!merchantRefNum || !fawryRefNumber) {
    await recordAudit(adminClient, "fawry", fawryRefNumber ?? null, merchantRefNum ?? null, payload, "missing_reference", "rejected", "merchantRefNum or fawryRefNumber absent");
    return new Response(JSON.stringify({ error: "Missing mandatory reference fields" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const payAmtMinor   = Math.round(Number(paymentAmount ?? "0") * 100);
  const orderAmtMinor = Math.round(Number(orderAmount ?? paymentAmount ?? "0") * 100);

  // ── 3. Cryptographic signature verification — Server Notification V2
  //       ALWAYS enforced (no environment bypass).
  const isValidSig = await verifyFawryNotificationSignature(
    fawryRefNumber,
    merchantRefNum,
    payAmtMinor,
    orderAmtMinor,
    String(orderStatus ?? ""),
    String(paymentMethod ?? "CARD"),
    paymentReferenceNumber ?? null,
    fawrySecretKey,
    sigToVerify,
  );

  if (!isValidSig) {
    // ── 3a. Detect charge-signature misuse: if the CHARGE formula matches, flag it explicitly
    const chargeSig = await buildFawryChargeSignature(
      "MERCHANT_CODE",
      merchantRefNum,
      null,
      String(paymentMethod ?? "CARD"),
      payAmtMinor,
      fawrySecretKey,
    );
    const eventType = chargeSig.toLowerCase() === sigToVerify.toLowerCase()
      ? "charge_signature_misuse"
      : "invalid_signature";

    await recordAudit(adminClient, "fawry", fawryRefNumber, merchantRefNum, payload, eventType, "rejected", "Signature mismatch");
    return new Response(JSON.stringify({ error: "Invalid Fawry notification signature" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── 4. Handle non-PAID statuses: acknowledge without settlement (per Fawry contract)
  if (orderStatus !== "PAID") {
    const isKnownStatus = FAWRY_ACK_STATUSES.has(String(orderStatus ?? ""));
    const status200     = isKnownStatus ? "acknowledged" : "unrecognised_status";
    await recordAudit(adminClient, "fawry", fawryRefNumber, merchantRefNum, payload, `order_${String(orderStatus).toLowerCase()}`, "processed", null);
    return new Response(
      JSON.stringify({ message: `Fawry event acknowledged`, orderStatus, status: status200 }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  // ── 5. Resolve payment attempt
  const { data: attempt, error: attErr } = await adminClient
    .from("payment_attempts")
    .select("id, amount_minor, currency, status, invoice_id")
    .eq("id", merchantRefNum)
    .maybeSingle();

  if (attErr || !attempt) {
    await recordAudit(adminClient, "fawry", fawryRefNumber, merchantRefNum, payload, "unknown_reference", "quarantined", "Attempt not found");
    return new Response(JSON.stringify({ error: "Payment attempt not found" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── 6. Amount financial validation (valid sig but wrong amount → quarantine)
  if (payAmtMinor !== attempt.amount_minor) {
    await recordAudit(adminClient, "fawry", fawryRefNumber, merchantRefNum, payload, "amount_mismatch", "quarantined",
      `Provider amount ${payAmtMinor} ≠ attempt amount ${attempt.amount_minor}`);
    return new Response(
      JSON.stringify({ error: "Amount mismatch: Fawry amount does not match authoritative payment attempt amount" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  // ── 7. Apply verified settlement
  const { data: result, error: settleErr } = await adminClient.rpc("apply_verified_payment", {
    p_attempt_id:     merchantRefNum,
    p_provider_tx_id: fawryRefNumber,
    p_amount_minor:   payAmtMinor,
    p_currency:       attempt.currency,
  });

  if (settleErr) {
    await recordAudit(adminClient, "fawry", fawryRefNumber, merchantRefNum, payload, "settlement_error", "quarantined", settleErr.message);
    return new Response(JSON.stringify({ error: settleErr.message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  await recordAudit(adminClient, "fawry", fawryRefNumber, merchantRefNum, payload, "payment_settled", "processed", null);

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
    // Audit failures must never block main flow
  }
}
