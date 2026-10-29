create table if not exists public.recipes (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
    name text not null check (length(trim(name)) > 0),
    category text not null check (category in ('Starter', 'Main', 'Snack', 'Dessert', 'Sauce')),
    cook_time_minutes integer not null check (cook_time_minutes > 0),
    servings integer not null default 1 check (servings > 0),
    calories integer not null default 0 check (calories >= 0),
    protein numeric not null default 0 check (protein >= 0),
    fat numeric not null default 0 check (fat >= 0),
    carbs numeric not null default 0 check (carbs >= 0),
    nutrition_is_estimated boolean not null default false,
    ingredients jsonb not null default '[]'::jsonb check (jsonb_typeof(ingredients) = 'array'),
    steps jsonb not null default '[]'::jsonb check (jsonb_typeof(steps) = 'array'),
    created_at timestamptz not null default now()
);

create index if not exists recipes_user_created_at_idx
    on public.recipes (user_id, created_at desc);

alter table public.recipes enable row level security;

create policy "Users can read their own recipes"
    on public.recipes for select
    using ((select auth.uid()) = user_id);

create policy "Users can create their own recipes"
    on public.recipes for insert
    with check ((select auth.uid()) = user_id);

create policy "Users can update their own recipes"
    on public.recipes for update
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);

create policy "Users can delete their own recipes"
    on public.recipes for delete
    using ((select auth.uid()) = user_id);
