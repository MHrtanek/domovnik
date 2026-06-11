import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')!

serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  const { user_id, building_id, full_name, email, type, message } = await req.json()

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)
  await supabase.from('feedback').insert({ user_id, building_id, full_name, email, type, message })

  const typeLabel = type === 'bug' ? 'Bug' : type === 'napad' ? 'Nápad' : 'Iné'

  await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: 'Domovník <noreply@domovnik.online>',
      to: 'hrtanekmatus02@gmail.com',
      subject: `Feedback [${typeLabel}] od ${full_name ?? 'používateľa'}`,
      html: `
        <h2>Nový feedback</h2>
        <p><strong>Typ:</strong> ${typeLabel}</p>
        <p><strong>Od:</strong> ${full_name ?? 'neznámy'} (${email ?? 'bez emailu'})</p>
        <p><strong>Správa:</strong></p>
        <blockquote style="border-left: 3px solid #1A3C6E; padding-left: 12px; color: #333;">${message}</blockquote>
        <p><a href="https://domovnik-admin.vercel.app/feedback">Zobraziť v admin paneli</a></p>
      `,
    }),
  })

  return new Response(JSON.stringify({ ok: true }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  })
})
