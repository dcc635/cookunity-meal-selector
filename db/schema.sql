-- CookUnity Meal Selector — order history schema
--
-- Create a fresh database with:
--   sqlite3 ~/.openclaw/workspace/cookunity.db < db/schema.sql
--
-- Safe to re-run against an existing database: CREATE TABLE IF NOT EXISTS is a
-- no-op, and the ALTER TABLE statements below are commented out because SQLite
-- has no "ADD COLUMN IF NOT EXISTS". See "Upgrading" at the bottom.

CREATE TABLE IF NOT EXISTS orders (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    meal_name    TEXT    NOT NULL,
    order_date   DATE    NOT NULL,           -- delivery date, YYYY-MM-DD
    meat_type    TEXT,                       -- Chicken | Beef | Pork | Lamb | Seafood
                                             -- | Turkey | Vegetarian | combos e.g. Chicken/Pork
    avoid        INTEGER NOT NULL DEFAULT 0, -- 1 = never suggest again
    snooze_until TEXT,                       -- YYYY-MM-DD; don't suggest before this date
    category     TEXT                        -- CookUnity menu section, verbatim.
                                             -- e.g. 'Meals | Protein & carb meals',
                                             --      'Breakfast | Morning plates'
);

-- Repeat-prevention queries filter on order_date and category on every run.
CREATE INDEX IF NOT EXISTS idx_orders_order_date ON orders (order_date);
CREATE INDEX IF NOT EXISTS idx_orders_category   ON orders (category);
CREATE INDEX IF NOT EXISTS idx_orders_meal_name  ON orders (meal_name);

-- Upgrading an older database that predates avoid / snooze_until / category:
--
--   ALTER TABLE orders ADD COLUMN avoid INTEGER NOT NULL DEFAULT 0;
--   ALTER TABLE orders ADD COLUMN snooze_until TEXT;
--   ALTER TABLE orders ADD COLUMN category TEXT;
--
-- Run only the ones missing from `sqlite3 <db> ".schema orders"`. Rows with a
-- NULL category are treated as regular (non-breakfast) meals by the exclusion
-- queries, so backfilling old rows is optional.
