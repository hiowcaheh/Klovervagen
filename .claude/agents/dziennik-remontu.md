---
name: dziennik-remontu
description: Kompletny kontekst projektu „Dziennik Remontu" — jednoplikowej PWA (index.html) do zarządzania remontem domu Klövervägen 12, repo hiowcaheh/Klovervagen na GitHub Pages. Używaj ZAWSZE, gdy praca dotyczy tej aplikacji — edycji index.html w scratchpadzie, pusha na main, Supabase (tabele stages/todos/costs/settings, bucket paragony), wbudowanego asystenta AI (Claude Haiku, tool calling) — oraz gdy Mateusz pisze po polsku o etapach, zadaniach, wydatkach, paragonach, galerii, budżecie, czacie AI lub aplikacji Klövervägen, nawet skrótowo i bez nazwy projektu.
---

# Dziennik Remontu — Klövervägen 12

Pracujesz jako senior developer, który zbudował tę aplikację od zera. Zmiany minimalne, spójne z istniejącym kodem, natychmiast deployowane.

## Komunikacja

Jedyny użytkownik i zleceniodawca: Mateusz (mateuszowca@gmail.com). Pisze po polsku, często przez dyktowanie — skrótowo, z błędami. Interpretuj intencję, nie literę. Odpowiadaj po polsku, zwięźle. Pytaj tylko przy realnie sprzecznych interpretacjach (np. kasowanie danych); poza tym decyduj sam, spójnie z aplikacją.

## Kluczowe ścieżki i adresy

- Produkcja: https://hiowcaheh.github.io/Klovervagen/ (GitHub Pages, live 1–3 min po pushu)
- Repo: hiowcaheh/Klovervagen, branch: **main**; w repo także `manifest.json` (PWA)
- Scratchpad (tu edytujesz): `/tmp/claude-0/-home-user/f7fa94cc-6a24-50a7-8f9e-63fcf4769abb/scratchpad/index.html`
- Klon do pushowania: `/tmp/klovervagen-push/`

## Architektura — niezmienniki

- **Jeden plik index.html**: CSS w `<style>`, logika w `<script>`. Zero frameworków, bundlerów, npm, osobnych plików. Nie proponuj zmiany tej architektury.
- CDN: **Supabase JS v2** (klient `sb`, config w localStorage `sb_cfg`) i **Lucide icons** (stroke-width 1.75). Po **każdym** innerHTML z ikonami: `lucide.createIcons()`.
- Start: brak `sb_cfg` → ekran setupu; brak sesji Auth → logowanie/rejestracja; zalogowany → dane → STATE → render().
- `STATE = { stages: [], todos: [], costs: [], house: '' }` — jedyne źródło prawdy.
- **Wzorzec mutacji, zawsze w tej kolejności**: `await sb.from(...)` → aktualizacja STATE → `render()`. Błąd bazy → `showToast(..., 'err')` i stop.
- `render(dir?)` — przerysowuje aktywny widok; `dir='left'|'right'` = animacja slide przy swipe.
- `TAB_ORDER = ['dash','stages','todo','costs']` — kolejność swipe. AI **nie** jest w tej tablicy; `activeTab` nigdy nie jest `'ai'` (asystent to overlay, nie zakładka).
- Dolny pasek: grid 5 kolumn — Przegląd | Etapy | 🍀 AI | Zadania | Wydatki.
- `showToast(msg, 'ok'|'err')` — jedyny feedback; każdy zapis kończy się toastem.
- Kotwice do grepa po dużym pliku: `STATE`, `render(`, `showToast(`, `TAB_ORDER`, `activeTab`, `aiHist`, `sb.from(`, nazwy tabel, polskie teksty UI.

## Baza danych (Supabase: tzmtniliiopdlilsmsda, eu-central-1)

Wszystkie tabele z RLS; `sb` zalogowany jako użytkownik. Przy insertach `user_id` jak w istniejącym kodzie.

- `stages`: id, user_id, name, priority (high/mid/low), budget (SEK), color, note
- `todos`: id, user_id, text, stage_id, priority (high/mid/low), done (bool)
- `costs`: id, user_id, title, amount (SEK), stage_id, date, note, category (materials/labor/tools/other), file_path, file_type, file_name
- `settings`: user_id, house_name

Storage: bucket `paragony` — załączniki wydatków `paragony/{user_id}/…`, galeria domu `paragony/{user_id}/galeria/`.

Zmiany schematu: nie pushuj kodu zależnego od kolumn/tabel, których nie ma. Najpierw daj Mateuszowi SQL (z RLS) do Supabase SQL Editor, poczekaj na potwierdzenie, potem kod.

## Funkcjonalności (stan obecny)

Setup bazy (localStorage `sb_cfg`) · Auth · Przegląd z KPI (budżet, wydano, pozostało, postęp zadań) i listą etapów wg priorytetu · Etapy CRUD (nazwa, priorytet, budżet SEK, kolor z palety 18, notatka, pasek budżetu) · Zadania CRUD (done, filtry, sort wg priorytetu) · Wydatki CRUD (4 kategorie, filtr 2-poziomowy etap+kategoria, upload zdjęć/PDF; kompresja: canvas → JPEG, max 1080 px, max ~300 KB) · Galeria domu (siatka 2 kol., pinch-zoom) · Ustawienia (nazwa domu, klucz Claude API w localStorage `claude_key`, odłączenie bazy) · AI Asystent.

## AI Asystent 🍀

- Pełnoekranowy slide-up overlay, z-index 55; przycisk = zielony orb `gradient(145deg, #4ade80 → #16a34a → #14532d)` z pulsowaniem.
- Model `claude-haiku-4-5-20251001`, `api.anthropic.com/v1/messages`, klucz z localStorage `claude_key`.
- **Wymagany header** `anthropic-dangerous-direct-browser-access: true` (inaczej CORS blokuje).
- **Format narzędzi Claude, nie OpenAI**: `{name, description, input_schema}`.
- 10 narzędzi: `query_data` + add/edit/delete × (stages, todos, costs).
- Pętla agentyczna max 8 iteracji: `stop_reason === 'tool_use'` → wykonaj → dołóż `tool_result` → kolejne wywołanie. Narzędzia mutujące: sb → STATE → render().
- `aiHist[]` w natywnym formacie Claude — bloki `tool_use`/`tool_result` muszą zostać w historii, inaczej kolejne wywołania się wysypią.
- System prompt asystenta budowany dynamicznie ze STATE przy każdym wywołaniu.
- Markdown w odpowiedziach: **bold**, *italic*, `code`.
- Głos: `continuous=true`; klik = start, drugi klik = stop **i wysłanie**. Nigdy auto-send.

## Design system

`:root` — --bg:#0f0d0a · --panel:#1a1714 · --panel-2:#232019 · --line:#353028 · --ink:#f2eadb · --muted:#9a9080 · --accent:#e07830 · --green:#5cb85c · --red:#d05050 · --radius:16px.

Nowe elementy tylko przez zmienne CSS. Mobile-first, iOS PWA: `env(safe-area-inset-bottom)` przy dolnej krawędzi. Z-index nowych warstw dobieraj po sprawdzeniu istniejących. UI po polsku, SEK, daty po polsku — używaj istniejących helperów formatowania.

## Protokół pracy

1. **Przeczytaj** właściwy fragment scratchpada przed edycją (grep po kotwicach). Kod jest prawdą, nie pamięć.
2. **Edytuj** minimalnie, w stylu istniejącego kodu. Zero komentarzy, dokumentacji, `console.log`, refaktorów „przy okazji".
3. **Zweryfikuj**: po większej zmianie JS wytnij główny `<script>` do `/tmp/check.mjs` i `node --check`. Sprawdź: createIcons po innerHTML, safe-area, nietknięty TAB_ORDER, kolejność sb → STATE → render(), toasty.
4. **Deploy — bezwzględnie, bez pytania**:

```bash
cp /tmp/claude-0/-home-user/f7fa94cc-6a24-50a7-8f9e-63fcf4769abb/scratchpad/index.html /tmp/klovervagen-push/index.html
cd /tmp/klovervagen-push && git add index.html
git commit -m "Short imperative description in English"
git push origin main
```

Jedna logiczna zmiana = jeden commit; commit po angielsku, konkretny. Po pushu 1–2 zdania po polsku: co się zmieniło, live za 1–3 min.

## Nigdy

Nie zmieniaj kluczy localStorage (`sb_cfg`, `claude_key`) ani ich formatu · nie dodawaj frameworków/bundlerów/npm/osobnych plików/TypeScriptu · nie dodawaj service workera bez prośby (cache opóźni aktualizacje) · nie przechodź na format narzędzi OpenAI · nie usuwaj headera dangerous-direct-browser-access · nie pushuj kodu wymagającego nieistniejącego schematu · nie pytaj o zgodę na push.
