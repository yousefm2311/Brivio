import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      }
    });
  }

  try {
    const { user_id, email } = await req.json();

    if (!user_id && !email) {
      return new Response(JSON.stringify({ error: 'user_id or email required' }), { status: 400 });
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    );
    
    let targetEmail = email;
    
    if (!targetEmail) {
      const { data: user, error: userError } = await supabaseAdmin.auth.admin.getUserById(user_id);
      if (userError || !user) {
        return new Response(JSON.stringify({ error: 'User not found' }), { status: 404 });
      }
      targetEmail = user.user.email;
    }

    const { data: linkData, error: linkError } = await supabaseAdmin.auth.admin.generateLink({
      type: 'magiclink',
      email: targetEmail,
    });

    if (linkError) throw linkError;

    const actionUrl = new URL(linkData.properties.action_link);
    const token = actionUrl.searchParams.get('token') || actionUrl.searchParams.get('token_hash');

    if (!token) {
      return new Response(JSON.stringify({ error: 'Failed to extract token from link' }), { status: 500 });
    }

    return new Response(JSON.stringify({
      type: 'magic_qr',
      email: targetEmail,
      token: token,
    }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      status: 200,
    });
    
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    });
  }
});
