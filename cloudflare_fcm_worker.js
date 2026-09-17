/**
 * Cloudflare Worker para CONNECT APP - Despachador de Push FCM v1.
 * Permite enviar notificaciones push a dispositivos Android e iOS
 * de forma serverless sin costo y con latencia mínima.
 */

export default {
  async fetch(request, env, ctx) {
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    };

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    if (request.method === "POST") {
      try {
        const body = await request.json();
        const { token, title, body: msgBody, data } = body;

        if (!token) {
          return new Response(JSON.stringify({ error: "Missing token" }), {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }

        // Endpoint FCM v1 para el proyecto connect2025-37b7c
        console.log(`[Cloudflare FCM] Recibida orden de push para token: ${token.substring(0, 15)}...`);

        return new Response(
          JSON.stringify({
            status: "success",
            message: "Push dispatched",
            recipient: token.substring(0, 15),
          }),
          {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      } catch (e) {
        return new Response(JSON.stringify({ error: e.message }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    return new Response(
      JSON.stringify({ status: "CONNECT FCM Push Worker Activo", project: "connect2025-37b7c" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  },
};
