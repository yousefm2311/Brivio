import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabaseUrl = Deno.env.get('SUPABASE_URL') as string
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') as string
const fcmProjectId = Deno.env.get('FCM_PROJECT_ID')

serve(async (req) => {
  try {
    const supabase = createClient(supabaseUrl, supabaseServiceKey)
    
    // Parse the webhook payload
    const payload = await req.json()
    
    // Check if the payload is from an insert into app_notifications
    if (payload.type !== 'INSERT' || payload.table !== 'app_notifications') {
      return new Response(JSON.stringify({ error: 'Invalid payload' }), { status: 400 })
    }

    const { user_id, title, message, type, reference_id } = payload.record

    if (!user_id) {
      return new Response(JSON.stringify({ error: 'No user_id provided' }), { status: 400 })
    }

    // Query active tokens for the user
    const { data: tokens, error: tokenError } = await supabase
      .from('device_push_tokens')
      .select('token')
      .eq('user_id', user_id)

    if (tokenError) {
      throw tokenError
    }

    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ message: 'No active push tokens found for user' }), { status: 200 })
    }

    const fcmTokens = tokens.map((t: any) => t.token)

    // FCM HTTP v1 API authentication
    // Note: In a production environment, you should obtain this OAuth2 access token dynamically 
    // using a service account JSON file, e.g., via googleapis package or a JWT flow.
    const fcmAccessToken = Deno.env.get('FCM_ACCESS_TOKEN') || 'mock-fcm-access-token'

    // Send the notification to each token
    const sendPromises = fcmTokens.map((token: string) => {
      return fetch(`https://fcm.googleapis.com/v1/projects/${fcmProjectId}/messages:send`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${fcmAccessToken}`
        },
        body: JSON.stringify({
          message: {
            token: token,
            notification: {
              title: title,
              body: message,
            },
            data: {
              type: type || '',
              reference_id: reference_id?.toString() || '',
            }
          }
        })
      })
    })

    const results = await Promise.all(sendPromises)
    const responses = await Promise.all(results.map(r => r.json()))

    return new Response(
      JSON.stringify({ message: 'Push notifications sent', responses }),
      { headers: { "Content-Type": "application/json" }, status: 200 }
    )
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    })
  }
})
