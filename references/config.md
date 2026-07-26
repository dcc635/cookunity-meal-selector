# CookUnity Meal Selector — Configuration

Edit this file after installing. Everything the skill needs to know about *your* setup lives
here; `SKILL.md` and `weekly-order.md` read from it and contain no personal values.

## Paths

| Setting | Value |
|---------|-------|
| Database path | `~/.openclaw/workspace/cookunity.db` |
| Browser profile | `openclaw` |

Expand `~` yourself when shelling out — `sqlite3 ~/.openclaw/workspace/cookunity.db "..."`
works in `sh -lc`, but pass an absolute path if you are constructing the command elsewhere.

## Schedule

| Setting | Value |
|---------|-------|
| Delivery day | `Sunday` |
| Order cron | `0 12 * * 5` (Friday 12:00 PM) |
| Timezone | `America/Los_Angeles` |
| Which delivery | `second` — the cron runs Friday and orders for the *second* upcoming Sunday, not the one two days away |

If your CookUnity cutoff is different, change `Which delivery` to `next` and adjust Step 0 of
`weekly-order.md` accordingly.

## Credentials

| Setting | Value |
|---------|-------|
| Source | `1password` |
| 1Password vault | `OpenClaw` |
| 1Password item | `CookUnity` |
| Fields | `username`, `password` |

Fetch command:

```bash
op item get 'CookUnity' --vault OpenClaw --fields username,password --reveal
```

Requires the `op` CLI and, for unattended runs, `OP_SERVICE_ACCOUNT_TOKEN` in the Gateway's
environment.

**Alternative — environment variables.** Set `Source` to `env` above and export
`COOKUNITY_USERNAME` / `COOKUNITY_PASSWORD` in the Gateway environment instead. Never write
credentials into this file; it is committed to git.

## Meal Mix

How many of each kind to order per week. Adjust freely — the weekly flow reads this table and
nothing else decides the mix.

| Count | Kind | Constraint |
|-------|------|------------|
| 3 | Premium full meal with meat | tagged `up Premium` on the menu |
| 2 | New / unrated full meal with meat | no rating shown yet |
| 1 | Breakfast | top-rated |
| 1 | Breakfast, vegetarian | rating > 4.5 |

**Total: 7 meals.**

Additional rules:

- Good meat variety across the meat-bearing picks (beef / chicken / pork / fish / shrimp) —
  avoid three chickens in one week.
- Never pick anything returned by the exclusion queries below.

## Repeat Windows

| Kind | Window |
|------|--------|
| Regular meals (`category NOT LIKE 'Breakfast%'`) | 42 days |
| Breakfast items (`category LIKE 'Breakfast%'`) | 14 days |

Breakfast gets a shorter window on purpose — the breakfast catalog is small enough that a
6-week block would exhaust it.

## Notifications

| Setting | Value |
|---------|-------|
| Channel | `telegram` |
| Target | `<your-telegram-chat-id>` |

Find your chat id with:

```bash
openclaw directory self --channel telegram
```

Set both to `none` to disable notifications entirely. Any channel OpenClaw has configured
works here (`telegram`, `discord`, `whatsapp`, …) — see `openclaw channels status`.
