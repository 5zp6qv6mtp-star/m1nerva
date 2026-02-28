// Self-host mode: point to same-origin server.py REST endpoint.
// The frontend uses /rest/v1/links on this origin.
window.MINERVA_SUPABASE_URL = window.location.origin;
window.MINERVA_SUPABASE_ANON_KEY = "local-dev-key";
