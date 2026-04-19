import { createClient } from "@supabase/supabase-js";

// Route all Supabase calls through Nginx (/supabase/) so the browser
// never needs to know the internal address — works from any access point
// (localhost, local network IP, Cloudflare tunnel, etc.)
const supabaseUrl = `${window.location.origin}/supabase`;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
