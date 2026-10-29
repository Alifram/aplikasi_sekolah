const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ message: "Metode tidak diizinkan." }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    console.error("Required Supabase function secrets are not configured.");
    return jsonResponse({ message: "Layanan login belum dikonfigurasi." }, 500);
  }

  let payload: { identifier?: unknown; password?: unknown };
  try {
    payload = await request.json();
  } catch {
    return jsonResponse({ message: "Format permintaan tidak valid." }, 400);
  }

  const identifier = typeof payload.identifier === "string"
    ? payload.identifier.trim()
    : "";
  const password = typeof payload.password === "string"
    ? payload.password
    : "";
  if (!identifier || !password || identifier.includes("@")) {
    return jsonResponse({ message: "Nomor induk atau password tidak valid." }, 400);
  }

  try {
    const profileUrl = new URL("/rest/v1/users", supabaseUrl);
    profileUrl.searchParams.set("select", "email");
    profileUrl.searchParams.set("nomor_induk", `eq.${identifier}`);
    profileUrl.searchParams.set("is_deleted", "eq.0");
    profileUrl.searchParams.set("limit", "1");

    const profileResponse = await fetch(profileUrl, {
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
      },
    });
    if (!profileResponse.ok) {
      console.error("Could not resolve account identifier.", profileResponse.status);
      return jsonResponse({ message: "Login gagal. Periksa data akun Anda." }, 401);
    }

    const profiles = await profileResponse.json();
    const email = Array.isArray(profiles) && typeof profiles[0]?.email === "string"
      ? profiles[0].email
      : null;
    if (!email) {
      return jsonResponse({ message: "Login gagal. Periksa data akun Anda." }, 401);
    }

    const authResponse = await fetch(
      new URL("/auth/v1/token?grant_type=password", supabaseUrl),
      {
        method: "POST",
        headers: {
          apikey: anonKey,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ email, password }),
      },
    );
    const authBody = await authResponse.json();
    if (!authResponse.ok) {
      return jsonResponse(
        { message: "Login gagal. Periksa data akun dan password Anda." },
        authResponse.status === 429 ? 429 : 401,
      );
    }

    return jsonResponse(authBody, 200);
  } catch (error) {
    console.error("Identifier login request failed.", error);
    return jsonResponse({ message: "Layanan login tidak dapat dihubungi." }, 502);
  }
});
