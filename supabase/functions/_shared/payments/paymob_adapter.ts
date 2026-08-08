import { crypto } from "https://deno.land/std@0.168.0/crypto/mod.ts";

/**
 * Paymob HMAC Helper according to official Paymob Transaction Callback specification.
 * Concatenates ordered transaction fields and computes SHA-512 HMAC digest.
 */
export async function computePaymobHmac(
  payloadObj: Record<string, any>,
  hmacSecret: string
): Promise<string> {
  const fields = [
    payloadObj.amount_cents,
    payloadObj.created_at,
    payloadObj.currency,
    payloadObj.error_occured,
    payloadObj.has_parent_transaction,
    payloadObj.id,
    payloadObj.integration_id,
    payloadObj.is_3d_secure,
    payloadObj.is_auth,
    payloadObj.is_capture,
    payloadObj.is_refunded,
    payloadObj.is_standalone_payment,
    payloadObj.is_voided,
    payloadObj.order?.id || payloadObj.order,
    payloadObj.owner,
    payloadObj.pending,
    payloadObj.source_data?.pan || "",
    payloadObj.source_data?.sub_type || "",
    payloadObj.source_data?.type || "",
    payloadObj.success,
  ];

  const concatenated = fields.map((v) => (v === undefined || v === null ? "" : String(v))).join("");
  const encoder = new TextEncoder();
  const keyData = encoder.encode(hmacSecret);
  const msgData = encoder.encode(concatenated);

  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    keyData,
    { name: "HMAC", hash: "SHA-512" },
    false,
    ["sign"]
  );

  const signatureBuffer = await crypto.subtle.sign("HMAC", cryptoKey, msgData);
  const sigArray = Array.from(new Uint8Array(signatureBuffer));
  return sigArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}
