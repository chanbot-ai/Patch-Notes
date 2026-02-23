# Supabase Project Audit Export (Patch Notes)

Date: 2026-02-23
Project Ref: `lvapccwqypcvhijmevbh`

This file is a shareable audit of the current Supabase schema/migration state for the Patch Notes project.

## Direct answers

### What tables already exist in migrations?

Yes. The baseline migration includes these `public` tables:

- `comments`
- `games`
- `post_metrics`
- `posts`
- `reaction_types`
- `reactions`
- `user_followed_games`
- `users`

Defined in:
- `/Users/chanlowran/Documents/Patch-Notes-v1/supabase/migrations/20260223045000_public_schema_baseline.sql` (`CREATE TABLE` lines around 131, 145, 159, 173, 214, 227, 240, 251)

### Are `post_metrics` and `reactions` already defined?

Yes.

- `post_metrics`: baseline migration line ~159
- `reaction_types`: baseline migration line ~214
- `reactions`: baseline migration line ~227

### Is `post_reaction_counts` already defined?

No.

- `public.post_reaction_counts` view/table does not currently exist in the live DB.

### Is `hot_feed_view` already defined?

Yes.

- `public.hot_feed_view` exists and is defined in the baseline migration.
- Baseline line refs:
  - comment header around line `188`
  - `CREATE VIEW public.hot_feed_view AS` around line `191`

### Are triggers already defined?

Yes (already present in the baseline/live DB).

Current trigger set:
- `auth.users` -> `on_auth_user_created` -> `public.handle_new_user`
- `public.posts` -> `post_insert_trigger` -> `public.create_post_metrics_row`
- `public.reactions` -> `reaction_insert_trigger` -> `public.update_post_metrics_on_reaction`
- `public.comments` -> `comment_insert_trigger` -> `public.update_post_metrics_on_comment`
- `public.post_metrics` -> `hot_score_trigger` -> `public.recalc_hot_score`

Baseline refs for public trigger functions/triggers:
- functions around lines `55`, `70`, `90`, `107`
- triggers around lines `354`, `361`, `368`, `375`

### Are onboarding flags already defined?

Yes.

- `public.users.onboarding_complete boolean DEFAULT false`
- Baseline ref: `/Users/chanlowran/Documents/Patch-Notes-v1/supabase/migrations/20260223045000_public_schema_baseline.sql` around line `256`

### Did the schema get modified beyond the original SQL snippets we discussed?

Yes.

Additional schema/security/privacy work was added after baseline capture, including:

- `auth.users -> public.users` auto-profile trigger migration + backfill
- grant tightening (`anon`/`authenticated`) on `users`, `posts`, `post_metrics`, `hot_feed_view`
- `public.users` RLS cleanup (removed redundant legacy insert policy)
- placeholder username helper/documentation (`generate_placeholder_username`)
- username validation functions + constraints (`is_placeholder_username`, `is_valid_app_username`, checks)
- `is_username_available(...)` RPC (security definer) for safe username availability checks
- `public_profiles` public-safe view (no email)
- `create_post_metrics_row()` hardened to `SECURITY DEFINER`

These are all tracked in migrations listed below.

### Are we using SQL migrations only (no dashboard edits)?

Historically: **No**.

What happened:
- Early schema/policy changes were made manually (Supabase SQL editor / direct SQL / dashboard-driven setup) before the local migration workflow was configured.
- Then a baseline migration was generated to capture the live `public` schema.
- After that, subsequent schema changes were applied via SQL migrations and `supabase db push`.

Important distinction:
- There have also been manual **data** edits (test rows, email confirmations, resetting tester profile state), which are intentionally not migrations.

### Do custom RLS policies already exist?

Yes.

Current live `public` RLS policies:

- `comments`
  - `Comments are viewable by everyone` (`SELECT`, roles `{public}`)
  - `Users can comment` (`INSERT`, roles `{public}`, `with_check = auth.uid() = user_id`)
- `posts`
  - `Posts are viewable by everyone` (`SELECT`, roles `{public}`)
  - `Users can insert posts` (`INSERT`, roles `{authenticated}`, `with_check = auth.uid() = author_id`)
- `reactions`
  - `Reactions are viewable by everyone` (`SELECT`, roles `{public}`)
  - `Users can react` (`INSERT`, roles `{public}`, `with_check = auth.uid() = user_id`)
- `user_followed_games`
  - `Users can follow games` (`INSERT`, roles `{public}`, `with_check = auth.uid() = user_id`)
- `users`
  - `users_rw_own` (`ALL`, roles `{authenticated}`, `using/check = id = auth.uid()`)

Note:
- The legacy public `SELECT` policy on `public.users` was removed (privacy hardening).
- Username availability now uses an RPC instead of public `SELECT` on `public.users`.

## Migration inventory (current local/remote aligned)

1. `20260223045000_public_schema_baseline.sql`
2. `20260223045440_auth_users_profile_trigger.sql`
3. `20260223050500_tighten_public_users_anon_grants.sql`
4. `20260223051200_tighten_authenticated_public_grants.sql`
5. `20260223052000_tighten_feed_object_anon_grants.sql`
6. `20260223052500_cleanup_redundant_users_rls_policy.sql`
7. `20260223053100_document_placeholder_username_strategy.sql`
8. `20260223054000_username_validation_strategy.sql`
9. `20260223060000_enable_authenticated_post_inserts.sql`
10. `20260223063500_lock_down_public_users_email_exposure.sql`
11. `20260223064500_create_public_profiles_view.sql`
12. `20260223065000_harden_post_metrics_trigger_function.sql`

## Current live public schema inventory (for planning next migrations)

### Tables (`public`)

- `comments`
- `games`
- `post_metrics`
- `posts`
- `reaction_types`
- `reactions`
- `user_followed_games`
- `users`

### Views (`public`)

- `hot_feed_view`
- `public_profiles`

## What this means for your upcoming requests

If you ask to add any of the following, they are **not all net-new**:

- `Add reaction views` -> likely **new** (depends which views; `post_reaction_counts` is not present)
- `Add post_reaction_counts` -> **new**
- `Add triggers` -> some already exist (post/comment/reaction/hot-score/auth-profile)
- `Add onboarding flags` -> `users.onboarding_complete` already exists
- `Add hot_feed_view` -> already exists

The safest next step is to define exactly which new tables/views/triggers are additive vs. replacements, then implement as new SQL migrations.

