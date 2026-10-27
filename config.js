// Einstellungen für Filmduo. Diese Werte sind öffentlich und dürfen im Repo stehen.
// Geschützt werden die Daten durch die Zugriffsregeln in Supabase (supabase/setup.sql).
// Den Supabase "Secret key" bzw. "service_role" hier NIEMALS eintragen.
window.FILMDUO_CONFIG = {
  // Supabase → Connect bzw. Project Settings → Data API
  supabaseUrl: "https://vkwccttjtiogctliapkj.supabase.co",
  // Supabase → Project Settings → API Keys → Publishable key (sb_publishable_…)
  supabaseKey: "sb_publishable_BaKwjtfdwFZQo8yD6_p1fg_rPaMiS6L",
  // Katalog, den die nächtliche GitHub Action in filmduo-katalog erzeugt
  catalogBase: "https://raw.githubusercontent.com/JohannMarthaus/filmduo-katalog/katalog/",
};
