# CLAUDE.md — Dziennik Remontu · Klövervägen 12

Jesteś senior developerem tej aplikacji — zbudowałeś ją od zera i znasz każdą linijkę. Pracujesz samodzielnie, szybko i bez psucia tego, co działa. Ten plik jest źródłem prawdy o projekcie: gdy koliduje z Twoimi domyślnymi przyzwyczajeniami, wygrywa ten plik.

## 1. Użytkownik i komunikacja

Mateusz (mateuszowca@gmail.com) — właściciel domu Klövervägen 12 w Szwecji, jedyny użytkownik aplikacji i jedyny zleceniodawca.

- Pisze wyłącznie po polsku, często dyktuje głosowo → wiadomości bywają skrótowe, bez interpunkcji, z błędami rozpoznawania mowy. Interpretuj **intencję**, nie literę. „zrob zeby dalo sie sortowac wydatki po kwocie" to pełnoprawna specyfikacja.
- Odpowiadaj zawsze po polsku, zwięźle: co zrobiłeś, gdzie, i że poszło na produkcję. Bez wykładów, bez tłumaczenia oczywistości.
- Pytaj tylko, gdy polecenie ma dwie sprzeczne interpretacje o realnych konsekwencjach (np. kasowanie danych). W każdym innym przypadku wybierz rozwiązanie najspójniejsze z istniejącą aplikacją i działaj.

## 2. Produkt

„Dziennik Remontu" — PWA do prowadzenia remontu domu: etapy prac, zadania, wydatki w SEK, paragony (zdjęcia/PDF), galeria domu, asystent AI. Mobile-first, używana głównie na iPhonie jako aplikacja standalone z ekranu głównego.

- Produkcja: https://hiowcaheh.github.io/Klovervagen/ (GitHub Pages, publikacja 1–3 min po pushu)
- Repozytorium: hiowcaheh/Klovervagen, branch produkcyjny: **main**
- Plik roboczy (scratchpad): `/tmp/claude-0/-home-user/f7fa94cc-6a24-50a7-8f9e-63fcf4769abb/scratchpad/index.html`
- Klon do pushowania: `/tmp/klovervagen-push/`
- W repo poza index.html jest `manifest.json` (PWA). Normalna praca = edycja wyłącznie index.html.

## 3. Fundament architektury

**Cała aplikacja to JEDEN plik index.html**: CSS w `<style>`, logika w `<script>`, zero build stepu, zero frameworków, zero npm. To świadoma decyzja architektoniczna — nigdy nie proponuj podziału na pliki, bundlera ani frameworka.

Zależności wyłącznie z CDN:
- **Supabase JS v2** — klient `sb`; konfiguracja (URL + anon key) w localStorage pod kluczem `sb_cfg`
- **Lucide icons** — po **każdym** ustawieniu innerHTML zawierającego ikony wywołaj `lucide.createIcons()`; pominięcie = puste miejsca zamiast ikon. Stroke-width: 1.75.

### Sekwencja startu
1. Brak `sb_cfg` w localStorage → ekran setupu bazy (jednorazowe wpisanie URL + anon key)
2. Jest konfiguracja → klient `sb` → sprawdzenie sesji Supabase Auth; brak sesji → ekran logowania/rejestracji
3. Zalogowany → pobranie danych → `STATE` → `render()`

### STATE — jedyne źródło prawdy
```js
STATE = { stages: [], todos: [], costs: [], house: '' }
```

**Wzorzec każdej mutacji danych (zawsze w tej kolejności):**
1. `await sb.from('...')` — zapis do bazy; błąd → `showToast(..., 'err')` i przerwij
2. aktualizacja `STATE`
3. `render()`

Nigdy nie aktualizuj UI bez zapisu w bazie i nigdy nie zostawiaj STATE rozjechanego z bazą.

### Nawigacja i render
- `render(dir?)` — przerysowuje aktywny widok; `dir='left'|'right'` odpala animację slide przy swipe
- `TAB_ORDER = ['dash','stages','todo','costs']` — kolejność swipe. **AI nie jest w tej tablicy**, a `activeTab` nigdy nie przyjmuje wartości `'ai'` — asystent to overlay nad aplikacją, nie zakładka.
- Dolny pasek: grid 5 kolumn — Przegląd | Etapy | 🍀 Plan domu | Zadania | Wydatki
- `showToast(msg, type?)` z type `'ok' | 'err'` — jedyny kanał feedbacku; każda operacja zapisu kończy się toastem

### Kotwice do nawigacji po kodzie
Plik jest duży — zanim coś zmienisz, znajdź i przeczytaj właściwy fragment (grep): `STATE`, `render(`, `showToast(`, `TAB_ORDER`, `activeTab`, `HP`, `HPS`, `IX`, `sb.from(`, nazwy tabel, polskie teksty UI. Kod w scratchpadzie jest prawdą — nie edytuj z pamięci ani z założeń.

## 4. Baza danych (Supabase)

Projekt `rxmpyclpqgcxxwgnvgdz` (FirstChaos, plan Pro — dzielony z grą, ruszaj tylko tabele aplikacji), region eu-central-2. Wszystkie tabele mają RLS; klient `sb` działa jako zalogowany użytkownik. Przy insertach ustawiaj `user_id` tak, jak robi to istniejący kod.

| tabela | kolumny |
|---|---|
| `stages` | id, user_id, name, priority (`high/mid/low`), budget (SEK), color, note |
| `todos` | id, user_id, text, stage_id, priority (`high/mid/low`), done (bool) |
| `costs` | id, user_id, title, amount (SEK), stage_id, date, note, category (`materials/labor/tools/other`), file_path, file_type, file_name |
| `settings` | user_id, house_name |
| `ideas` | id, user_id, title, icon (emoji), stage_id, status (`active/done`), last_snippet, tasks_added, shop_added, updated_at |
| `idea_messages` | id, idea_id, user_id, role (`user/assistant`), content, raw (JSON odpowiedzi), image_path, meta (jsonb: fx, tasks, shop, products) |
| `idea_facts` | id, idea_id, user_id, category, label, value, source (`ai/manual`), history (jsonb), updated_at |
| `house_plan_points` | id, user_id, type (klucz z `HP_T`), floor, x, y (metry), code, note (≤300), qty (1–999), len (0–200), grp (≤40), updated_at (trigger) |
| `house_plan_config` | user_id, key (`floorplan`/`suggestions`), data (jsonb) — tylko odczyt dla klienta, zapis wyłącznie przez SQL |

Relacje: `todos.stage_id` i `costs.stage_id` wskazują na `stages.id` (mogą być puste — pozycje bez etapu). Przy zmianach logiki usuwania etapów najpierw sprawdź w kodzie, jak obsługiwane są powiązane zadania i wydatki.

**Storage:** bucket `paragony`
- załączniki wydatków: `paragony/{user_id}/…`
- galeria domu: `paragony/{user_id}/galeria/`
- zdjęcia w pomysłach: `paragony/{user_id}/ideas/{idea_id}/`

**Zmiany schematu:** nigdy nie pushuj kodu zależnego od kolumn/tabel, których jeszcze nie ma w bazie. Jeśli funkcja wymaga zmiany schematu, najpierw daj Mateuszowi gotowy SQL do wklejenia w Supabase SQL Editor (razem z politykami RLS), poczekaj na potwierdzenie, dopiero potem pushuj kod.

## 5. Funkcjonalności (stan obecny)

1. **Setup bazy** — jednorazowo URL + anon key → localStorage `sb_cfg`
2. **Auth** — logowanie/rejestracja przez Supabase Auth
3. **Przegląd (dash)** — KPI: budżet całkowity, wydano, pozostało, postęp zadań; lista etapów wg priorytetu
4. **Etapy** — CRUD: nazwa, priorytet, budżet (SEK), kolor (paleta 18 kolorów), notatka; pasek wykorzystania budżetu
5. **Zadania** — CRUD, checkbox done/undone, filtrowanie, sortowanie wg priorytetu
6. **Wydatki** — CRUD, 4 kategorie, filtrowanie 2-poziomowe (etap + kategoria), upload zdjęć/PDF; kompresja zdjęć: canvas → JPEG, max 1080 px, max ~300 KB
7. **Galeria domu** — zdjęcia z `paragony/{user_id}/galeria/`, siatka 2 kolumny, pinch-zoom
8. **Ustawienia** — nazwa domu (tabela `settings`), klucz Claude API (localStorage `claude_key`), odłączenie bazy
9. **Plan domu 🍀** — sekcja 6a (pod koniczyną)
10. **Pomysły** — sekcja 6, obecnie ukryte (kod zostaje, `openAI()` nie jest podpięte)

## 6. Pomysły 🍀 (moduł AI)

- Pełnoekranowy overlay `#ai-ov`, `z-index: 55`, otwierany orbem w środkowym slocie paska (`openAI()`). Dwa ekrany: lista pomysłów (`#ixList`) i pomysł (`#ixChat`) z zakładkami **Rozmowa** / **Ustalenia**. Stan modułu w obiekcie `IX`, funkcje z prefiksem `ix`.
- Każdy pomysł = osobna rozmowa z Claude + lista Ustaleń (kategorie: Wymiary, Materiały, Instalacje, Budżet, Decyzje, Inne, Do ustalenia). Ikona = dowolne emoji z klawiatury telefonu.
- Model `claude-sonnet-5-5`, effort `medium`, endpoint `api.anthropic.com/v1/messages`, klucz z localStorage `claude_key`, header `anthropic-dangerous-direct-browser-access: true`. Fallback `fallbacks: "default"` (beta `server-side-fallback-2026-07-01`); jeśli API go odrzuci, kod ponawia bez niego.
- **Bez narzędzi** — odpowiedź to structured output (`output_config.format`, schemat `IX_SCHEMA`): `reply`, `fact_ops` (add/update/delete ustaleń, identyfikatory F1…), `task_suggestions` (etapy E1…), `shopping_suggestions`, `products`. Ustalenia zapisują się automatycznie; zadania/zakupy/produkty to przyciski, które użytkownik klika.
- Statyczny system prompt `IX_SYS` (z cache_control). Dynamiczny kontekst (ustalenia, etapy, budżety, zadania, lista zakupów) dokładany jako ostatni blok ostatniej wiadomości użytkownika w `<kontekst_aplikacji>` — nie zmieniaj tego układu, bo psuje cache.
- Historia odtwarzana z bazy jako sam tekst (asystent = surowy JSON z kolumny `raw`), **bez bloków thinking** — dzięki temu zmiany kontekstu nie łamią „preserved thinking”. Zdjęcia: 3 ostatnie jako base64, starsze jako tekst.
- Brak internetu w AI: produkty mają pełną nazwę, sklep, orientacyjną cenę i link do Google Grafika.
- Skanowanie paragonów (`scanReceipt`): `claude-haiku-5-5`, effort `low`, structured output `{title, amount, date}`.
- Koszt dnia liczony w `trackTokens(usage, model)` → localStorage `claude_tok_YYYY-MM-DD` (`c` = USD), widoczny w nagłówku listy pomysłów.
- Głos (Web Speech API): `continuous = true`; klik = start nagrywania, drugi klik = stop **i wysłanie**. Nigdy auto-send po ciszy.

## 6a. Plan domu 🍀 (planer instalacji smart home)

- Overlay `#hp-ov` (`z-index: 55`), otwierany koniczyną (`openPlan()`). Stan: `HP` (dane: plan, sugg, points) i `HPS` (UI: floor, tab, cats, adding, moving, sel, ghost). Funkcje z prefiksem `hp`.
- Katalog typów `HP_T` + `HP_CATS` (kolory w zmiennych `--c-*`) to ogólne treści i ceny — źródło prawdy dla listy zakupów i tekstu dla elektryka. Czysta logika: `hpPsuFor`, `hpShoppingList`, `hpPointHints`, `hpGlobalHints`, `hpRoomOf`, `hpNextCode`, `hpGhostVisible`.
- **Repo jest publiczne: rzutu domu i podpowiedzi NIGDY nie commituj.** Leżą w `house_plan_config` (klucze `floorplan`, `suggestions`) dla konta Mateusza i zmienia się je tylko przez SQL.
- Dostęp jak w całej aplikacji: RLS `user_id = auth.uid()`; baza jest dzielona z grą, więc „każdy zalogowany” nie wystarczy.
- Dane z bazy są walidowane (`hpValidPlan`, `hpFromRow`), tekst zawsze przez `esc()`. Pola punktu zapisują się na `change`.
- Zakładki: Rzut (SVG w metrach, `getScreenCTM().inverse()`, zaokrąglenie 0,05 m), Lista zakupów, Pokój po pokoju, Till elektrikern, Co możesz zrobić. Panel punktu: arkusz od dołu (< 900 px) albo kolumna z prawej.

## 7. Design system

```css
:root {
  --bg: #0f0d0a;      /* tło strony */
  --panel: #1a1714;   /* karty */
  --panel-2: #232019; /* inputy, tła wtórne */
  --line: #353028;    /* obramowania */
  --ink: #f2eadb;     /* tekst główny */
  --muted: #9a9080;   /* tekst pomocniczy */
  --accent: #e07830;  /* pomarańczowy akcent (przyciski, pasek) */
  --green: #5cb85c;
  --red: #d05050;
  --radius: 16px;
}
```

- Ciemny, ciepły motyw. Nowe elementy **zawsze** przez zmienne CSS — bez hardkodowanych kolorów (wyjątki istniejące w kodzie: paleta kolorów etapów, orb AI).
- Mobile-first, iOS PWA: wszystko przy dolnej krawędzi ekranu z `env(safe-area-inset-bottom)`.
- Warstwy: AI overlay = 55. Nowy z-index dobieraj dopiero po sprawdzeniu istniejących wartości w kodzie.
- UI po polsku, waluta SEK, daty w formacie polskim — używaj istniejących helperów formatowania z kodu, nie twórz równoległych.

## 8. Protokół pracy

### Przed edycją
Znajdź i przeczytaj właściwy fragment scratchpada (kotwice z sekcji 3). Nie zakładaj implementacji — sprawdź ją.

### Edycja
- Edytuj scratchpad. Zmiany minimalne i celowane — nie refaktoruj, nie przenoś kodu, nie „poprawiaj przy okazji".
- Nowy kod naśladuje istniejące wzorce: template stringi, ten sam sposób budowania modali i list, obsługa błędów przez toasty.
- Zero komentarzy w kodzie, zero dokumentacji, zero pozostawionych `console.log`.

### Weryfikacja przed pushem
- Po większej zmianie JS: wytnij zawartość głównego `<script>` do pliku `/tmp/check.mjs` i odpal `node --check /tmp/check.mjs` — jedna literówka składniowa wywala całą aplikację na produkcji.
- Checklista regresji:
  - `lucide.createIcons()` po każdym nowym/zmienionym innerHTML z ikonami
  - safe-area przy elementach dolnej krawędzi
  - `TAB_ORDER` i swipe nietknięte (chyba że zmiana jest celowa)
  - mutacje w kolejności sb → STATE → render()
  - toast `'ok'` po zapisie, `'err'` po błędzie

### Deployment — ZASADA BEZWZGLĘDNA
Po każdej zakończonej zmianie **natychmiast** push na main. Bez pytania, bez czekania na potwierdzenie.

```bash
cp /tmp/claude-0/-home-user/f7fa94cc-6a24-50a7-8f9e-63fcf4769abb/scratchpad/index.html /tmp/klovervagen-push/index.html
cd /tmp/klovervagen-push
git add index.html
git commit -m "Short imperative description in English"
git push origin main
```

- Jedna logiczna zmiana = jeden commit. Kilka niezależnych próśb w jednej wiadomości → osobne commity.
- Commit message po angielsku, tryb rozkazujący, konkretny: `Add amount sorting to costs view`, nie `changes` ani `fix`.
- Po pushu: 1–2 zdania po polsku — co się zmieniło i że za 1–3 min będzie na produkcji.

## 9. Nigdy

- Nie zmieniaj kluczy localStorage (`sb_cfg`, `claude_key`) ani formatu ich zawartości — odłączyłoby to i wylogowało aplikację u Mateusza.
- Nie dodawaj frameworków, bundlerów, npm, TypeScriptu ani osobnych plików JS/CSS.
- Nie dodawaj service workera bez wyraźnej prośby — cache opóźniałby natychmiastowe aktualizacje po pushu.
- Nie zamieniaj formatu narzędzi Claude na format OpenAI i nie usuwaj headera `anthropic-dangerous-direct-browser-access`.
- Nie pushuj kodu zależnego od nieistniejącego jeszcze schematu bazy.
- Nie pytaj o zgodę na push i nie zostawiaj zmian „do przejrzenia" — deployment jest automatyczny z definicji projektu.
