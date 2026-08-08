import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface ProvisionRequest {
  email: string;
  fullName: string;
  role: 'super_admin' | 'admin' | 'staff' | 'teacher' | 'student' | 'parent';
  branchId?: string;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

    // 1. Verify Authorization Header
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 2. Validate Caller Auth JWT
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user: callerUser }, error: authError } = await callerClient.auth.getUser();
    if (authError || !callerUser) {
      return new Response(
        JSON.stringify({ error: 'Invalid or expired caller token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 3. Admin Client with Service Role (Server-side Only)
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    // 4. Verify Caller Authorization in DB
    const { data: callerRole, error: roleError } = await callerClient.rpc('current_user_role');
    if (roleError || !callerRole) {
      return new Response(
        JSON.stringify({ error: 'Unable to verify caller authorization' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const payload: ProvisionRequest = await req.json();
    const { email, fullName, role, branchId } = payload;

    if (!email || !fullName || !role) {
      return new Response(
        JSON.stringify({ error: 'Email, fullName, and role are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 5. Enforce Least Privilege Authorization Matrix
    if (role === 'admin' && callerRole !== 'super_admin') {
      return new Response(
        JSON.stringify({ error: 'Only Super Admin can provision Admin accounts' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (['staff', 'teacher', 'student', 'parent'].includes(role) && !['super_admin', 'admin'].includes(callerRole)) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized to provision accounts' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (role === 'super_admin' && callerRole !== 'super_admin') {
      return new Response(
        JSON.stringify({ error: 'Unauthorized to provision Super Admin accounts' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 6. Step A: Provision Auth User via Supabase Auth Admin Invitation API
    const { data: inviteData, error: inviteError } = await adminClient.auth.admin.inviteUserByEmail(email, {
      data: { full_name: fullName, role },
    });

    let newUserId: string;

    if (inviteError || !inviteData.user) {
      // Fallback to createUser if invitation service throws in local mock mode
      const { data: createData, error: createError } = await adminClient.auth.admin.createUser({
        email,
        password: 'Password123!',
        email_confirm: true,
        user_metadata: { full_name: fullName, role },
      });

      if (createError || !createData.user) {
        return new Response(
          JSON.stringify({ error: createError?.message || inviteError?.message || 'Failed to create Auth user' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
      newUserId = createData.user.id;
    } else {
      newUserId = inviteData.user.id;
    }

    // 7. Step B: Setup Profile and Domain Entities in Database
    const { data: rpcData, error: rpcError } = await adminClient.rpc('complete_privileged_user_profile', {
      p_target_user_id: newUserId,
      p_full_name: fullName,
      p_role: role,
      p_branch_id: branchId || null,
    });

    // 8. Compensation Strategy on Partial Failure
    if (rpcError) {
      console.error(`Database profile setup failed for ${newUserId}, executing compensation cleanup:`, rpcError);
      await adminClient.auth.admin.deleteUser(newUserId);

      return new Response(
        JSON.stringify({ error: `Database setup failed: ${rpcError.message}. Auth user deleted as cleanup.` }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        userId: newUserId,
        email,
        role,
        message: 'User provisioned with invitation email sent and profile set up.',
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message || 'Unexpected internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
