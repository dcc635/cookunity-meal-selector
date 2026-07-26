---
name: cookunity-meal-selector
description: Select, swap, and confirm CookUnity weekly meals via browser automation, with SQLite-backed repeat prevention. Use when asked to pick this week's meals, replace/swap/exchange a meal in a CookUnity order, or check what was ordered recently.
version: 1.0.0
metadata:
  openclaw:
    emoji: 🍽️
    homepage: https://github.com/dcc635/cookunity-meal-selector
    os:
      - macos
      - linux
    requires:
      bins:
        - sqlite3
    install:
      - kind: brew
        formula: sqlite
        bins:
          - sqlite3
---

# CookUnity Meal Selector

Automates the weekly CookUnity order: picks meals that respect a no-repeats history,
confirms the order in the browser, and logs what was ordered to SQLite.

**Read `references/config.md` first.** Every path, credential location, meal-mix rule, and
notification target lives there. Nothing in this file is user-specific — if a value looks
like it should be personal, it is in the config.

Two entry points:

| Ask | Go to |
|-----|-------|
| "pick this week's meals", or the weekly cron job fires | `references/weekly-order.md` |
| "swap X for Y", "replace the salmon" | [Swap Flow](#swap-flow) below |

## Setup

- Browser profile: the value of `Browser profile` in `references/config.md`
- Edit URL: `https://subscription.cookunity.com/meals?date=YYYY-MM-DD&edit=true`
- DB: `sqlite3 "$COOKUNITY_DB"` — see `Database path` in `references/config.md`
- Always use `compact:true, depth:1` on snapshots (`depth:2` for the weekly flow)

## Date Calculation

Delivery is the day named in `Delivery day` in `references/config.md` (default Sunday).
The edit URL uses the **day before** delivery. E.g. delivery Apr 12 → URL date `2026-04-11`.

## Swap Flow

### 1. Navigate to edit page

```
https://subscription.cookunity.com/meals?date=YYYY-MM-DD&edit=true
```

The cart sidebar appears at the top of the snapshot showing all meals with minus/plus buttons.

### 2. Remove the old meal

Click the `minus` button for the target meal in the cart sidebar. The cart count drops by 1.

### 3. Add the new meal

**If the meal appears in the main menu list** (has a ref in the current snapshot):
- Click its link directly from the edit page — it opens the product detail page
- Click "Add meal" or "Add extra for $X" button
- Click the "back Back" button OR navigate back to the edit URL

**If the meal is NOT in the main menu** (e.g. new items, search-only):
- Click Search button from the edit page
- Type the meal name in the search box
- Click the search result link → product detail page opens
- Click "Add meal" button — URL changes to `products/...?edit=true&date=...&afterCutoff=true`
- Do NOT click Continue from the product page — navigate back to the edit URL directly
- Verify the meal appears in the cart sidebar at the expected total count

### 4. Confirm

From the edit page with correct cart:
- Click Continue (use `evaluate` to click all Continue buttons if ref is ambiguous:
  `Array.from(document.querySelectorAll('button')).filter(b => b.textContent.trim() === 'Continue').forEach(b => b.click())`)
- Review the order summary page — verify meals and total
- Click "Confirm order"

### 5. Update the DB

```sql
-- Remove old meal
DELETE FROM orders WHERE meal_name LIKE '%<old meal>%' AND order_date = 'YYYY-MM-DD';
-- Add new meal
INSERT INTO orders (meal_name, order_date, meat_type, category)
VALUES ('<full meal name>', 'YYYY-MM-DD', '<meat_type>', '<CookUnity category>');
```

Meat types: `Chicken`, `Beef`, `Pork`, `Lamb`, `Seafood`, `Vegetarian`, `Turkey`, or combos
like `Chicken/Pork`. Order date = delivery day in `YYYY-MM-DD` format.

## Meal Selection Rules

### Repeat Prevention

Before suggesting meals for a new week, always query the DB to filter out recent orders.
The windows are configurable — see `Repeat windows` in `references/config.md`.

The `category` column stores the CookUnity section exactly as shown on the menu page
(e.g. `Breakfast | Morning plates`, `Meals | Protein & carb meals`,
`Breakfast | Breakfast sweets`). Use it directly — no keyword guessing.

**Regular meals** — exclude anything ordered inside the regular window (default 42 days):

```sql
SELECT meal_name FROM orders
WHERE order_date >= date('now', '-42 days')
  AND (category IS NULL OR category NOT LIKE 'Breakfast%');
```

**Breakfast items** (`category LIKE 'Breakfast%'`) — exclude anything ordered inside the
breakfast window (default 14 days):

```sql
SELECT meal_name FROM orders
WHERE order_date >= date('now', '-14 days')
  AND category LIKE 'Breakfast%';
```

**Avoided or snoozed meals** — always exclude:

```sql
SELECT DISTINCT meal_name FROM orders
WHERE avoid = 1
   OR (snooze_until IS NOT NULL AND snooze_until > date('now'));
```

Run all three exclusion checks before presenting suggestions.

### Logging meals

Always include `category` from the CookUnity menu section header (e.g. `Meals | Soups & stews`,
`Breakfast | Morning plates`) when inserting. Without it, breakfast-vs-regular repeat
windows cannot be applied on later runs.

### Marking preferences

```sql
-- Never suggest again
UPDATE orders SET avoid = 1 WHERE meal_name = '<meal name>';
-- Pause a meal until a date
UPDATE orders SET snooze_until = 'YYYY-MM-DD' WHERE meal_name = '<meal name>';
```

## Common Pitfalls

- **Continue button ambiguous ref**: use the JS `evaluate` approach above.
- **Add button missing on direct URL navigation**: the "Add meal" button only appears when
  navigating through the SPA (from search results or menu). Direct URL navigation won't show
  it. Always use the search flow for items not in the main menu.
- **Cart reverts after search**: the cart persists as long as you stay in the SPA. After
  adding from the product page, navigate back to the edit URL (`/meals?date=...&edit=true`) —
  don't use browser back or navigate to the search URL.
- **Snacks upsell dialog**: may appear after clicking Continue. Dismiss it or click Continue again.
- **Duplicate add**: if you accidentally add qty=2, click minus once to reduce back to 1
  before confirming.
