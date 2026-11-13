-- ME Portalen: kör hela skriptet en gång i Supabase (SQL Editor -> New query -> Run).
-- Skapar tabellen för portalens data och en privat lagringsyta för originalfiler.
-- Varje inloggad användare kommer bara åt sina egna rader och filer.

create table if not exists public.portal_state (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  key text not null,
  data text not null default '',
  updated_at timestamptz not null default now(),
  primary key (user_id, key)
);

alter table public.portal_state enable row level security;

drop policy if exists "portal_state egen data" on public.portal_state;
create policy "portal_state egen data" on public.portal_state
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create or replace function public.portal_touch() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists portal_touch on public.portal_state;
create trigger portal_touch before insert or update on public.portal_state
  for each row execute function public.portal_touch();

insert into storage.buckets (id, name, public)
values ('portal-files', 'portal-files', false)
on conflict (id) do nothing;

drop policy if exists "portal-files egna filer" on storage.objects;
create policy "portal-files egna filer" on storage.objects
  for all to authenticated
  using (bucket_id = 'portal-files' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'portal-files' and (storage.foldername(name))[1] = auth.uid()::text);
