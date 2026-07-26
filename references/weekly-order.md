# Weekly Order Runbook

This is the flow the cron job runs. Read `config.md` first — every value written as
`<from config>` below comes from there.

## TOKEN EFFICIENCY RULES (CRITICAL)

- ALWAYS use `compact:true` and `depth:2` on every snapshot
- NEVER take screenshots unless absolutely necessary to resolve an ambiguity
- Do NOT narrate steps verbosely — act, then move on
- Batch actions when refs are known — don't snapshot after every single click unless needed

## CONFIRM-FIRST RULE (CRITICAL)

If you ever land on a page showing an order summary with a `Confirm order` button — CLICK IT
IMMEDIATELY before doing anything else. Do not snapshot, do not screenshot, do not read the
page. Just click Confirm. A half-edited order that never gets confirmed means no delivery.

## Step 0 — Calculate Delivery Date FIRST

The job runs on the cron day (default Friday). With `Which delivery = second` in `config.md`,
the delivery date is the SECOND upcoming delivery day — not the one two days away, the one
after it.

```python
import datetime
DELIVERY_WEEKDAY = 6  # Sunday; Mon=0 … Sun=6. Match `Delivery day` in config.md.
WHICH = 2             # `second` in config.md; use 1 for `next`

today = datetime.date.today()
days_ahead = (DELIVERY_WEEKDAY - today.weekday()) % 7
if days_ahead == 0:
    days_ahead = 7  # today is a delivery day — roll to the next one
delivery = today + datetime.timedelta(days=days_ahead + 7 * (WHICH - 1))
print(delivery.isoformat())  # use THIS date for everything below
```

Use the printed date for the edit-URL date (delivery minus 1 day), the SQLite `order_date`,
and the notifications.

## Step 0.5 — Notify Start

Send to `<Channel from config>` / `<Target from config>`:

> 🛒 Starting CookUnity meal selection for `<delivery date>`…

Skip if `Target` is `none`.

## Step 1 — Fetch Credentials

Per `Credentials` in `config.md`. For the 1Password default:

```bash
op item get 'CookUnity' --vault OpenClaw --fields username,password --reveal
```

Parse username (field 1) and password (field 2). **Do NOT log them** — not in the transcript,
not in a notification, not in an error message.

## Step 2 — Build Exclusion List (sqlite only)

Run all three queries against `<Database path from config>` and skip any meal appearing in any
result. Window values come from `Repeat windows` in `config.md`.

**Regular meals ordered inside the regular window:**

```bash
sqlite3 "$COOKUNITY_DB" "SELECT meal_name FROM orders WHERE order_date >= date('now', '-42 days') AND (category IS NULL OR category NOT LIKE 'Breakfast%');"
```

**Breakfast items ordered inside the breakfast window:**

```bash
sqlite3 "$COOKUNITY_DB" "SELECT meal_name FROM orders WHERE order_date >= date('now', '-14 days') AND category LIKE 'Breakfast%';"
```

**Avoided or snoozed meals:**

```bash
sqlite3 "$COOKUNITY_DB" "SELECT DISTINCT meal_name FROM orders WHERE avoid = 1 OR (snooze_until IS NOT NULL AND snooze_until > date('now'));"
```

Do this *before* opening the browser — it is cheap, and it tells you what to look for.

## Step 3 — Log In to CookUnity

- Open `https://www.cookunity.com` with `profile=<Browser profile from config>`
- Take a compact snapshot (`compact:true, depth:2`)
- Click **Log In** (NOT "Continue with Google")
- Enter the username and password from Step 1
- Submit the form

## Step 4 — Navigate to the Correct Week

- Navigate to `https://subscription.cookunity.com/`
- Take a compact snapshot (`compact:true, depth:2`)
- Find the week tab for the delivery date from Step 0 and click it
- Once on that week:
  - If you see a `Confirm order` button — click it immediately (CONFIRM-FIRST RULE)
  - If you see meals already in the cart — click Continue, then Confirm
  - If you see a `Browse Menu` button — click it (the cart appears on that page), then
    Continue, then Confirm

## Step 5 — Select Meals

Follow the `Meal Mix` table in `config.md` exactly — counts, kinds, and constraints.

Apply the Step 2 exclusions to every pick. Keep meat variety across the meat-bearing picks.

Use compact snapshots (`compact:true, depth:2`) throughout. Once the full mix is in the cart,
click Continue.

## Step 6 — Confirm Order IMMEDIATELY

As soon as the order summary / confirmation page loads, click `Confirm order` BEFORE any other
action.

## Step 7 — Log to SQLite

Use the delivery date from Step 0. For each meal ordered:

```bash
sqlite3 "$COOKUNITY_DB" "INSERT INTO orders (meal_name, order_date, meat_type, category) VALUES ('<meal_name>', '<YYYY-MM-DD>', '<meat_type>', '<category>');"
```

`meat_type`: `Chicken`, `Beef`, `Pork`, `Lamb`, `Seafood`, `Turkey`, `Vegetarian`, or a combo
like `Chicken/Pork`.

`category`: copy the CookUnity menu section header verbatim (e.g. `Meals | Soups & stews`,
`Breakfast | Morning plates`). **Do not skip this** — next week's breakfast-vs-regular repeat
windows depend on it.

Escape single quotes in meal names by doubling them (`Chef''s`).

## Step 8 — Notify Result

Success → `<Channel>` / `<Target>`:

> ✅ CookUnity order confirmed for `<delivery date>`!
> `<list each meal>`
> Total: $`<amount>`

Failure → `<Channel>` / `<Target>`:

> ⚠️ CookUnity order failed: `<exact issue>`

**Never finish silently.** A silent failure looks identical to a success until the box doesn't
show up.
