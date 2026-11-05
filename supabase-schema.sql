-- À coller dans Supabase > SQL Editor > Run
create table public.profiles(
  id uuid primary key references auth.users on delete cascade,
  name text not null default 'Étudiant', role text not null default 'student',
  created_at timestamptz default now());
create function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into public.profiles(id,name) values(new.id, coalesce(new.raw_user_meta_data->>'name','Étudiant')); return new; end $$;
create trigger on_signup after insert on auth.users for each row execute function public.handle_new_user();
create function public.is_admin() returns boolean language sql stable security definer set search_path=public as
$$ select exists(select 1 from public.profiles where id=auth.uid() and role='admin') $$;

create table public.tasks(id uuid primary key default gen_random_uuid(), title text not null, done boolean default false,
  starred boolean default false, due timestamptz, remind_at timestamptz, scope text not null default 'private' check(scope in('private','shared')),
  list text default 'Mes tâches', owner uuid not null default auth.uid() references auth.users, assignee text, created_at timestamptz default now());
create table public.events(id uuid primary key default gen_random_uuid(), title text not null, starts_at timestamptz not null, location text,
  created_by uuid not null default auth.uid() references auth.users, created_at timestamptz default now());
create table public.messages(id uuid primary key default gen_random_uuid(), body text not null, author uuid not null default auth.uid() references auth.users,
  author_name text, created_at timestamptz default now());
create table public.documents(id uuid primary key default gen_random_uuid(), title text not null, path text not null, size bigint,
  uploaded_by uuid not null default auth.uid() references auth.users, created_at timestamptz default now());

alter table public.profiles enable row level security; alter table public.tasks enable row level security;
alter table public.events enable row level security; alter table public.messages enable row level security; alter table public.documents enable row level security;

create policy p_sel on profiles for select to authenticated using(true);
create policy p_upd on profiles for update to authenticated using(is_admin());
create policy t_sel on tasks for select to authenticated using(scope='shared' or owner=auth.uid());
create policy t_ins on tasks for insert to authenticated with check(owner=auth.uid());
create policy t_upd on tasks for update to authenticated using(scope='shared' or owner=auth.uid() or is_admin());
create policy t_del on tasks for delete to authenticated using(owner=auth.uid() or is_admin());
create policy e_sel on events for select to authenticated using(true);
create policy e_ins on events for insert to authenticated with check(created_by=auth.uid());
create policy e_mod on events for update to authenticated using(created_by=auth.uid() or is_admin());
create policy e_del on events for delete to authenticated using(created_by=auth.uid() or is_admin());
create policy m_sel on messages for select to authenticated using(true);
create policy m_ins on messages for insert to authenticated with check(author=auth.uid());
create policy m_del on messages for delete to authenticated using(author=auth.uid() or is_admin());
create policy d_sel on documents for select to authenticated using(true);
create policy d_ins on documents for insert to authenticated with check(uploaded_by=auth.uid());
create policy d_del on documents for delete to authenticated using(uploaded_by=auth.uid() or is_admin());

insert into storage.buckets(id,name,public,file_size_limit) values('docs','docs',false,20971520) on conflict do nothing;
create policy s_sel on storage.objects for select to authenticated using(bucket_id='docs');
create policy s_ins on storage.objects for insert to authenticated with check(bucket_id='docs');
create policy s_del on storage.objects for delete to authenticated using(bucket_id='docs' and (owner=auth.uid() or is_admin()));

alter publication supabase_realtime add table tasks, events, messages, documents;

-- APRÈS ton inscription sur le site, te nommer admin (remplace l'e-mail) :
-- update public.profiles set role='admin' where id=(select id from auth.users where email='TON_EMAIL');
