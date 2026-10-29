# Recipes

Recipes is a native SwiftUI recipe collection and cooking companion for iPhone. It targets iOS 17 and uses Supabase for email/password authentication, per-user Postgres data, and the authenticated `ai` Edge Function. It does not use SwiftData.

## Requirements

- Xcode 16.2 or newer
- iOS 17 or newer (simulator or device)
- Supabase project
- XcodeGen to regenerate the project definition (`brew install xcodegen`; optional if opening the checked-in project)
- Supabase CLI for deploying the Edge Function
- Gemini API key stored only as a Supabase Edge Function secret

## Configure Supabase

1. In the Supabase dashboard, open **SQL Editor** and run [`supabase/schema.sql`](./supabase/schema.sql). This creates the `recipes` table and user-scoped RLS policies.
2. In **Project Settings → API**, copy the project URL and anon/public key.
3. Copy `Config/Secrets.xcconfig.example` to `Config/Secrets.xcconfig`. Replace the placeholder host and key. Keep the `https:/$()/` form at the start of the URL; Xcode expands the empty expression to the two slashes in `https://`.
4. The local secrets file is ignored by git. The app reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from its generated `Info.plist`. Do not put an elevated database key in the app.
5. In **Authentication → Providers**, enable Email. Configure email confirmation to match your preferred development setup.
6. To add the Sauce category to an existing database, run [`supabase/migrations/20261029_add_sauce_category.sql`](./supabase/migrations/20261029_add_sauce_category.sql) in the Supabase SQL Editor.

The app starts with an empty recipe collection. Create recipes from the home screen; untouched sample recipes from older app versions are removed automatically on the next load.

## Deploy the AI Edge Function

From the project directory, authenticate and link the Supabase CLI to your project:

```sh
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase secrets set GEMINI_API_KEY=YOUR_GEMINI_API_KEY
supabase functions deploy ai
```

[`supabase/config.toml`](./supabase/config.toml) disables gateway JWT verification because the function validates the bearer token itself with Supabase Auth. The app invokes the function with the current user's Supabase session. The function calls Gemini server-side using the `GEMINI_API_KEY` secret; no Gemini credential is included in the app.

The function requests structured JSON for instruction improvement, per-serving nutrition estimates, and complete recipe drafts from a description and/or image. Recipe drafts include category, timing, servings, ingredients, steps, and estimated nutrition for review in the editor. Photos are resized and compressed on-device before being sent to the authenticated Edge Function. Gemini API quotas and free-tier availability depend on Google's current terms and limits.

## Open and run

The Xcode project is generated from `project.yml` with XcodeGen and included as `Recipes.xcodeproj`.

```sh
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
# Edit Config/Secrets.xcconfig with your Supabase project URL and anon key.
open Recipes.xcodeproj
```

If you edit `project.yml`, regenerate with `xcodegen generate`.

Select the **Recipes** scheme and an iOS 17+ iPhone simulator, then run. Xcode resolves the official [`supabase-swift`](https://github.com/supabase/supabase-swift) package on the first build.

For a real device, select a development team under **Signing & Capabilities**, connect an iPhone running iOS 17+, and run the same scheme. Use a valid email address for account creation; if email confirmation is on, confirm before signing in.

## Included flows

- Animated launch mark, sign-in/sign-up, persisted Supabase session, and sign-out settings
- Five saved accent color choices and a custom tomato-and-plate app icon
- Searchable category-filtered adaptive recipe grid, pull-to-refresh, and optimistic CRUD with rollback
- Add/edit form with editable, reorderable ingredients, free-form steps, nutrition fields, and AI review previews
- Recipe detail with per-serving nutrition, ingredient and method sections, delete confirmation, and cook mode
- Ingredient checklist, step-by-step cooking, duration timer, awake screen, haptics, and subtle system sounds
- Automatic system appearance support, VoiceOver labels, and Dynamic Type-friendly SwiftUI layouts
