import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing Authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { resource_id } = await req.json();
    if (!resource_id) {
      return new Response(
        JSON.stringify({ error: "Missing required field: resource_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid user token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Fetch resource details from database
    const { data: resource, error: resError } = await supabaseAdmin
      .from("lesson_resources")
      .select("id, lesson_id, bucket, object_path")
      .eq("id", resource_id)
      .single();

    if (resError || !resource) {
      return new Response(
        JSON.stringify({ error: "Lesson resource not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Execute server-side lesson access authorization check
    const { data: canAccess, error: accessError } = await supabaseAdmin.rpc(
      "current_student_can_access_lesson",
      { p_lesson_id: resource.lesson_id }
    );

    if (accessError || !canAccess) {
      return new Response(
        JSON.stringify({ error: "Access denied to requested curriculum resource" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Generate signed URL with centralized TTL (900 seconds / 15 minutes)
    const { data: signedData, error: signError } = await supabaseAdmin
      .storage
      .from(resource.bucket)
      .createSignedUrl(resource.object_path, 900);

    if (signError || !signedData) {
      return new Response(
        JSON.stringify({ error: "Failed to generate signed URL" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        signed_url: signedData.signedUrl,
        expires_in_seconds: 900,
        resource_id: resource.id,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message ?? "Unexpected server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
