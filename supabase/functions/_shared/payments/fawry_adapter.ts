import { crypto } from "https://deno.land/std@0.168.0/crypto/mod.ts";
import { minorUnitsToDecimalString } from "./money_converter.ts";

/**
 * myFawry Charge Request Signature Helper
 * Formula: HEX(SHA256(merchantCode + merchantRefNum + customerProfileId + paymentMethod + amountDecimal + secretKey))
 */
export async function buildFawryChargeSignature(
  merchantCode: string,
  merchantRefNum: string,
  customerProfileId: string | null,
  paymentMethod: string,
  amountMinor: number,
  secretKey: string
): Promise<string> {
  const formattedAmount = minorUnitsToDecimalString(amountMinor);
  const custId = customerProfileId ? customerProfileId : "";
  const rawString = `${merchantCode}${merchantRefNum}${custId}${paymentMethod}${formattedAmount}${secretKey}`;
  const encoder = new TextEncoder();
  const data = encoder.encode(rawString);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

/**
 * Fawry Server Notification V2 Signature Verifier
 * Formula: HEX(SHA256(fawryRefNumber + merchantRefNum + paymentAmountDecimal + orderAmountDecimal + orderStatus + paymentMethod + paymentRefNum + secretKey))
 */
export async function verifyFawryNotificationSignature(
  fawryRefNumber: string,
  merchantRefNum: string,
  paymentAmountMinor: number,
  orderAmountMinor: number,
  orderStatus: string,
  paymentMethod: string,
  paymentRefNum: string | null,
  secretKey: string,
  receivedSignature: string
): Promise<boolean> {
  const payAmtFormatted = minorUnitsToDecimalString(paymentAmountMinor);
  const orderAmtFormatted = minorUnitsToDecimalString(orderAmountMinor);
  const payRef = paymentRefNum ? paymentRefNum : "";
  const rawString = `${fawryRefNumber}${merchantRefNum}${payAmtFormatted}${orderAmtFormatted}${orderStatus}${paymentMethod}${payRef}${secretKey}`;

  const encoder = new TextEncoder();
  const data = encoder.encode(rawString);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const expectedSig = hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");

  return expectedSig.toLowerCase() === receivedSignature.toLowerCase();
}
