# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

DMoney is a Vietnamese personal-finance ledger built with Vue 3, Vite, and Supabase. It is also configured as an installable PWA. The UI is Vietnamese; source files use UTF-8.

## Commands

- `npm install` — install dependencies.
- `npm run dev` — start Vite at `http://localhost:3000`. `strictPort` is enabled, so the server exits instead of selecting another port; this URL must match the Supabase Magic Link redirect configuration.
- `npm run build` — create/validate the production bundle (includes Vue SFC compilation and PWA generation).
- `npm run preview` — serve the built bundle locally.
- `npm test` — run tests with Node's built-in test runner (`node --test`). No lint script is defined. Tests can be run individually with `node --test <test-file>`.

## Architecture

`src/main.js` mounts the root `src/App.vue` and imports global/base and appearance styles. `App.vue` owns application state, authentication lifecycle, data loading, computed ledger/debt/report data, and mutation handlers. It composes focused page and modal components under `src/components/`; keep business state and coordination in the root unless a change clearly calls for extracting logic.

`src/supabase.js` is the data-access boundary: it creates the Supabase client, wraps authentication, table CRUD, and debt RPC calls. The root loads entries, tags, debt data, and events after a session is available. Event entries are also loaded per event. Debt mutations use database RPCs so their related ledger/debt updates remain coordinated.

Pure calculation and formatting logic is separated into `src/utils/`: `ledger.js` calculates chronological running balances and searches entries; `date.js` handles timezone-aware date keys and periods; `money.js` parses and formats amounts; `report.js` builds monthly summaries. The balance calculation must use the complete transaction history, not a filtered or paginated view. Amounts below zero represent expenses and positive amounts represent income. Adjustment and transfer entries affect balances but are excluded from daily reporting; debt-linked ledger rows have special reporting handling in `App.vue`.

`supabase_schema.sql` is the database schema and rerunnable migration source, including row-level security, user ownership, ledger/event/tag/debt tables, and debt RPC functions. Coordinate schema changes with `src/supabase.js` and the UI; do not treat the SQL file as documentation only. `vite.config.js` configures Vue, the fixed local port, and PWA manifest/auto-update behavior.

## Supabase setup and data conventions

The app expects `.env` values `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`; `VITE_APP_ENV=local` enables anonymous sign-in for local testing, which must also be enabled in Supabase Auth. Production uses the Magic Link login flow. See `README.md` for Supabase setup, redirect URLs, deployment, and existing-data migration notes. Never replace per-user RLS with public access without an explicit request.

The ledger table is `entries`; money is represented as signed amounts, and `entry_type` distinguishes ordinary transactions, adjustments, and transfers. A transfer is represented by paired entries linked with a `transfer_id`. Account types are `cash`, `bank`, and `wallet`. Debt accounts, debt entries, and monthly plans are maintained through SQL RPCs; preserve their coordinated money/debt accounting when changing that flow.

## Existing repository guidance

`AGENTS.md` contains the detailed Vietnamese UI behavior, styling, encoding, migration, commit, and push/PR requirements. Follow it alongside this file. In particular, preserve the existing notebook/ledger visual style, avoid unrelated restructuring or generated-file changes, and run `npm run build` after source changes. `README.md` documents Supabase setup and deployment. No Cursor or Copilot instruction files were found.
