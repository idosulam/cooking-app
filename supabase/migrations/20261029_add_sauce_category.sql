alter table public.recipes
    drop constraint if exists recipes_category_check;

alter table public.recipes
    add constraint recipes_category_check
    check (category in ('Starter', 'Main', 'Snack', 'Dessert', 'Sauce'));
