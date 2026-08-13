import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value.trim());
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { token, password } = await req.json();
    if (!token || !password || password.length < 6) {
      return new Response(JSON.stringify({ error: 'QR token and a 6+ character password are required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const tokenHash = await sha256Hex(token);
    const { data: qrRows, error: qrError } = await adminClient
      .from('account_login_qr_tokens')
      .select('id, profile_id, expires_at, status')
      .eq('token_hash', tokenHash)
      .eq('status', 'active')
      .limit(1);

    const qr = qrRows?.[0];
    if (qrError || !qr || new Date(qr.expires_at).getTime() <= Date.now()) {
      return new Response(JSON.stringify({ error: 'Invalid or expired QR token' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { data: profile, error: profileError } = await adminClient
      .from('profiles')
      .select('id, email, full_name, role')
      .eq('id', qr.profile_id)
      .single();

    if (profileError || !profile || !['student', 'parent', 'teacher', 'staff', 'admin'].includes(profile.role)) {
      return new Response(JSON.stringify({ error: 'QR account is not supported' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { error: updateError } = await adminClient.auth.admin.updateUserById(profile.id, {
      password,
      email_confirm: true,
      user_metadata: {
        full_name: profile.full_name,
        role: profile.role,
        password_reset_required: false,
      },
    });

    if (updateError) {
      return new Response(JSON.stringify({ error: updateError.message }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    await adminClient
      .from('account_login_qr_tokens')
      .update({
        status: 'revoked',
        consumed_at: new Date().toISOString(),
        consumed_by: profile.id,
      })
      .eq('id', qr.id);

    await adminClient
      .from('profiles')
      .update({ updated_at: new Date().toISOString() })
      .eq('id', profile.id);

    return new Response(JSON.stringify({
      success: true,
      email: profile.email,
      fullName: profile.full_name,
      role: profile.role,
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message || 'Unexpected internal server error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
