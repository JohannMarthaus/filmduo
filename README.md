# Filmduo

Swipe-App für zwei: Beide wischen Filme und Serien, gemeinsame Likes werden zu Matches.

**App:** https://johannmarthaus.github.io/filmduo/

## So funktioniert's

1. Seite öffnen, Namen eingeben, **Duo erstellen**.
2. Über **Einladung teilen** den Link an deinen Partner schicken. Der Code ist im Link schon drin.
3. Beide swipen. Wischt ihr denselben Titel nach rechts, ist es ein Match.

Auf dem Handy über „Zum Home-Bildschirm“ (iPhone/Safari) bzw. „App installieren“ (Android/Chrome) ablegen, dann startet Filmduo wie eine App.

## Aufbau

| Datei / Ordner | Inhalt |
|---|---|
| `index.html` | Die komplette App (Oberfläche, Logik, Startkatalog als Notfall-Reserve) |
| `config.js` | Supabase-Adresse, Publishable key und Adresse des Katalogs. Alles öffentliche Werte. |
| `supabase/setup.sql` | Tabellen, Zugriffsregeln und Funktionen für Supabase. Einmal im SQL Editor ausführen, gefahrlos wiederholbar. |
| `vendor/supabase-2.117.3.js` | Supabase-Bibliothek (MIT-Lizenz, siehe `vendor/supabase-LICENSE.txt`), lokal abgelegt statt über ein CDN |
| `manifest.webmanifest`, `icon*` | Name und Symbol für den Home-Bildschirm |
| `.nojekyll` | Sagt GitHub Pages, dass die Dateien unverändert ausgeliefert werden sollen |

## Woher die Daten kommen

- **Katalog:** Das Repo [filmduo-katalog](https://github.com/JohannMarthaus/filmduo-katalog) holt jede Nacht per GitHub Action Filme und Serien von TMDB und legt sie auf den Branch `katalog`. Die App lädt `meta.json` und `chunks/c00.json …` direkt von dort und merkt sich den Stand im Browser.
- **Duo, Swipes, Matches:** Supabase-Projekt `filmduo` (Region Frankfurt). Anmeldung ohne Konto (anonyme Anmeldung). Die Zugriffsregeln (Row Level Security) sorgen dafür, dass nur die zwei Mitglieder eines Duos dessen Swipes sehen und niemand im Namen des anderen swipen kann.

## Sicherheit

- Der **Publishable key** in `config.js` darf öffentlich sein. Er erlaubt nur, was die Regeln in `setup.sql` zulassen.
- Der **Secret key** bzw. `service_role` von Supabase kommt **nie** in dieses Repo.
- Die anonyme Kennung hängt am Browser. Wer Browserdaten löscht oder das Gerät wechselt, ist für die App eine neue Person und erstellt mit seinem Partner ein neues Duo.

## Hinweis

Diese App verwendet die TMDB-API, ist aber weder von TMDB unterstützt noch zertifiziert. Streaminganbieter: JustWatch.
