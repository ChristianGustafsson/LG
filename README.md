# Är vi ett verkligt team? – ledningsgruppstest

Ett webbtest som ledningsgruppen gör enskilt. Svaren summeras och analyseras automatiskt: gruppens snitt, en pyramid med de tre villkoren för ett verkligt team, hur spridda svaren är, påståenden där ni är oeniga, allas uppdragsbeskrivningar sida vid sida, och konkreta rekommendationer.

Bygger på testet ”Är din ledningsgrupp ett pseudoteam?” i VD-tidningen nr 6 2026 (organisationspsykolog Mattias Engström). Påståendena är omformulerade.

- **Kod:** statisk HTML/JS i det här repot, publiceras gratis med GitHub Pages.
- **Svar:** lagras i en egen Supabase-databas (gratisnivån räcker). Inga svar hamnar någonsin i repot.
- **Inga konton:** deltagarna svarar via en länk. Vd:n får en separat adminlänk.

## Kom igång (cirka 10 minuter)

### 1. Skapa databasen i Supabase
1. Skapa ett konto och ett nytt projekt på [supabase.com](https://supabase.com). Välj gärna region *EU (Frankfurt/Stockholm)*.
2. Öppna **SQL Editor → New query**, klistra in hela innehållet i [`supabase/schema.sql`](supabase/schema.sql) och klicka **Run**.
3. Gå till **Project Settings → API** (eller knappen **Connect**) och kopiera:
   - **Project URL**, till exempel `https://abcdefghijkl.supabase.co`
   - den publika nyckeln **anon / publishable**. Använd *inte* service_role-nyckeln.

### 2. Lägg in nycklarna
Redigera [`config.js`](config.js) direkt på GitHub (pennikonen) och fyll i:

```js
window.LG_CONFIG = {
  SUPABASE_URL: "https://abcdefghijkl.supabase.co",
  SUPABASE_ANON_KEY: "eyJhbGciOi..."
};
```

Den publika nyckeln får ligga öppet. Den ger bara åtkomst till de funktioner som `schema.sql` öppnar, inte till tabellerna.

### 3. Publicera med GitHub Pages
**Settings → Pages → Build and deployment → Source: Deploy from a branch → Branch: `main` / `(root)` → Save.**
Efter någon minut ligger testet på `https://christiangustafsson.github.io/LG/`.

### 4. Skapa testet för din ledningsgrupp
1. Öppna sidan, skriv gruppens namn och klicka **Skapa test**.
2. Du får två länkar:
   - **Deltagarlänken** skickar du till ledningsgruppen.
   - **Adminlänken** behåller du själv. Spara den, den går inte att återskapa.
3. Varje person svarar enskilt. Resultatet visas för en deltagare först när hen själv har svarat. Med adminlänken ser du alltid resultatet.

## Funktioner

| | Deltagare | Vd (adminlänk) |
|---|---|---|
| Svara och ändra sina svar (från samma webbläsare) | ✓ | ✓ |
| Se sammanställningen | efter eget svar | alltid |
| Se *vem* som har svarat | – | ✓ (bara namn, aldrig svar) |
| Kopiera underlag för AI-analys till Claude | – | ✓ |
| Starta ny omgång (sparar historik, rensar svar) | – | ✓ |

## Anonymitet och säkerhet

- Sammanställningen visar inga namn. Uppdragsbeskrivningar och kommentarer visas i en ordning som inte följer svarsordningen.
- Namnfältet är frivilligt och syns bara med adminlänken, så att vd:n ser vem som har svarat.
- Tabellerna har Row Level Security utan policyer. Webbläsaren kommer bara åt data via de kontrollerade funktionerna i `schema.sql`.
- Svaren är *inte* tekniskt anonyma för den som administrerar Supabase-projektet: där syns vilket namn (om angivet) som hör till vilka svar. Säg det till gruppen hellre än att lova full anonymitet.
- Varje deltagare identifieras med en slumpad nyckel i webbläsaren. Den som byter dator eller rensar webbläsaren räknas som en ny deltagare.

## Filer

```
index.html            sidan
app.js                logik: frågor, poäng, analys, anrop till Supabase
style.css             utseende (ljust och mörkt läge)
config.js             Supabase-adress och publik nyckel
supabase/schema.sql   tabeller, säkerhet och funktioner
```

Testet är ett reflektionsverktyg, inte en vetenskaplig diagnos.
