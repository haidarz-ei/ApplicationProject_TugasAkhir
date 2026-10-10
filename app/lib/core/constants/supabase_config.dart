/// Konfigurasi koneksi Supabase.
///
/// Anon key aman dipakai di client-side — keamanan data dikontrol
/// oleh Row Level Security (RLS) di sisi Supabase, bukan dari key ini.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR_PROJECT_ID.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.YOUR_SUPABASE_ANON_KEY',
  );
}
