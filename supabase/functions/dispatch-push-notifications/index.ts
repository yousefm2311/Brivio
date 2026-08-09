import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "https://esm.sh/jose@5.9.6";

type Delivery = {
  delivery_id: string;
  notification_id: string;
  user_id: string;
  title: string;
  body: string;
  data: Record<string, unknown>;
  tokens: string[];
};

type ServiceAccount = {
  client_email: string;
  private_key: string;
  project_id: string;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")!;

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false },
});

async function getAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  const privateKey = await importPKCS8(serviceAccount.private_key, "RS256");
  const jwt = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(serviceAccount.client_email)
    .setSubject(serviceAccount.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt()
    .setExpirationTime("55m")
    .sign(privateKey);

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!response.ok) {
    throw new Error(`Firebase OAuth failed: ${response.status} ${await response.text()}`);
  }

  const body = await response.json();
  return body.access_token;
}

async function sendToToken(
  projectId: string,
  accessToken: string,
  token: string,
  delivery: Delivery,
) {
  const data: Record<string, string> = {};
  for (const [key, value] of Object.entries(delivery.data ?? {})) {
    data[key] = typeof value === "string" ? value : JSON.stringify(value);
  }
  data.notification_id = delivery.notification_id;
  data.delivery_id = delivery.delivery_id;

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title: delivery.title,
            body: delivery.body,
          },
          data,
          android: {
            priority: "HIGH",
            notification: {
              channel_id: "academy_notifications",
              sound: "default",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
        },
      }),
    },
  );

  if (!response.ok) {
    throw new Error(`FCM send failed: ${response.status} ${await response.text()}`);
  }
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const serviceAccount = JSON.parse(serviceAccountJson) as ServiceAccount;
  const { data, error } = await supabase.rpc("claim_pending_push_deliveries", {
    p_limit: 50,
  });

  if (error) {
    return Response.json({ error: error.message }, { status: 500 });
  }

  const deliveries = (data ?? []) as Delivery[];
  const accessToken = await getAccessToken(serviceAccount);
  let sent = 0;
  let failed = 0;
  let skipped = 0;

  for (const delivery of deliveries) {
    if (!delivery.tokens?.length) {
      skipped++;
      await supabase.rpc("mark_push_delivery_result", {
        p_delivery_id: delivery.delivery_id,
        p_status: "skipped",
        p_error: "No active device tokens",
      });
      continue;
    }

    try {
      await Promise.all(
        delivery.tokens.map((token) =>
          sendToToken(serviceAccount.project_id, accessToken, token, delivery)
        ),
      );
      sent++;
      await supabase.rpc("mark_push_delivery_result", {
        p_delivery_id: delivery.delivery_id,
        p_status: "sent",
        p_error: null,
      });
    } catch (error) {
      failed++;
      await supabase.rpc("mark_push_delivery_result", {
        p_delivery_id: delivery.delivery_id,
        p_status: "failed",
        p_error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  return Response.json({ claimed: deliveries.length, sent, failed, skipped });
});
