import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Roles permitted to trigger payment reconciliation
const RECONCILE_ALLOWED_ROLES = new Set(["super_admin", "admin", "staff"]);

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl      = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseAnonKey  = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const adminClient = createClient(supabaseUrl, supabaseServiceKey);

  // ── 1. Authentication check
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Missing authorization header" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── 2. Verify token and get user
  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) {
    return new Response(JSON.stringify({ error: "Invalid or expired token" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── 3. Authorization: only admin/staff can reconcile
  const { data: profile, error: profileErr } = await adminClient
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single();

  if (profileErr || !profile || !RECONCILE_ALLOWED_ROLES.has(profile.role)) {
    return new Response(JSON.stringify({ error: "Insufficient permissions for reconciliation" }), {
      status: 403,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── 4. Parse body
  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { attempt_id } = body;
  if (!attempt_id) {
    return new Response(JSON.stringify({ error: "Missing attempt_id" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── 5. Load payment attempt
  const { data: attempt, error: fetchErr } = await adminClient
    .from("payment_attempts")
    .select("*, invoices(total_minor, amount_paid_minor, currency, status)")
    .eq("id", attempt_id)
    .maybeSingle();

  if (fetchErr || !attempt) {
    return new Response(JSON.stringify({ error: "Payment attempt not found" }), {
      status: 404,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── 6. Already settled → idempotent response
  if (attempt.status === "succeeded") {
    return new Response(
      JSON.stringify({ message: "Attempt already settled", status: "succeeded", invoice_id: attempt.invoice_id }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  // ── 7. Query provider for current status (fixture mode for local/test)
  //       Production would call Paymob/Fawry API here.
  //       Fixture: provider_reference = "FIXTURE-{SUCCESS|PENDING|FAILED}-{provider_tx_id}"
  const providerStatus = resolveProviderFixtureStatus(attempt.provider_reference);

  if (providerStatus === null) {
    // No fixture → report current DB status without settling
    return new Response(
      JSON.stringify({ status: attempt.status, invoice_id: attempt.invoice_id, message: "Provider query not available (sandbox)" }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  if (providerStatus.status !== "SUCCESS") {
    // Provider confirms non-success → no settlement
    return new Response(
      JSON.stringify({ status: attempt.status, provider_status: providerStatus.status, invoice_id: attempt.invoice_id }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  // ── 8. Provider confirmed SUCCESS → settle via verified settlement path
  const { data: result, error: settleErr } = await adminClient.rpc("apply_verified_payment", {
    p_attempt_id:     attempt_id,
    p_provider_tx_id: providerStatus.txId,
    p_amount_minor:   attempt.amount_minor,
    p_currency:       attempt.currency,
  });

  if (settleErr) {
    return new Response(JSON.stringify({ error: settleErr.message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ ...result, reconciled_via: "fixture" }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});

/**
 * Resolves provider status from a deterministic test fixture encoded in provider_reference.
 * Format: "FIXTURE-{SUCCESS|PENDING|FAILED}-{provider_tx_id}"
 * Returns null if the reference is not a fixture (production path).
 */
function resolveProviderFixtureStatus(
  providerReference: string | null,
): { status: "SUCCESS" | "PENDING" | "FAILED"; txId: string } | null {
  if (!providerReference?.startsWith("FIXTURE-")) return null;

  const parts = providerReference.split("-");
  // Format: FIXTURE-SUCCESS-txId  → parts = ["FIXTURE", "SUCCESS", "txId"]
  if (parts.length < 3) return null;

  const status = parts[1] as "SUCCESS" | "PENDING" | "FAILED";
  const txId   = parts.slice(2).join("-");

  if (!["SUCCESS", "PENDING", "FAILED"].includes(status)) return null;
  return { status, txId };
}
