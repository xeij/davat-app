-- Davat schema. Run once in the Supabase SQL editor.

create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  display_name text not null default '',
  venmo text not null default '',
  cashtag text not null default ''
);

create table public.invites (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references auth.users on delete cascade,
  title text not null default '',
  starts_at timestamptz,
  location text not null default '',
  details text not null default '',
  design jsonb not null,
  poster_path text check (poster_path is null or poster_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.png$'), -- <host id>/<invite id>.png
  price_cents int check (price_cents >= 0), -- null means no fundraiser
  host_pays boolean not null default false,
  time_zone text, -- the host's IANA zone, e.g. America/Chicago, for showing starts_at
  updated_at timestamptz not null default now()
);

create table public.responses (
  id uuid primary key default gen_random_uuid(),
  invite_id uuid not null references public.invites on delete cascade,
  name text not null check (length(name) between 1 and 60),
  user_id uuid references auth.users on delete cascade,
  guest_token text,
  rsvp text not null check (rsvp in ('going', 'maybe', 'cant')),
  paid boolean not null default false,
  check (user_id is not null or guest_token is not null),
  constraint responses_guest_unique unique (invite_id, guest_token),
  constraint responses_user_unique unique (invite_id, user_id)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  invite_id uuid not null references public.invites on delete cascade,
  name text not null check (length(name) between 1 and 60),
  user_id uuid references auth.users on delete cascade,
  guest_token text,
  body text not null check (length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index messages_invite_idx on public.messages (invite_id, created_at);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  invite_id uuid not null, -- no FK, so reports outlive a deleted invite
  reason text not null check (length(reason) between 1 and 1000),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.invites enable row level security;
alter table public.responses enable row level security;
alter table public.messages enable row level security;
alter table public.reports enable row level security;

-- profiles: each user reads and writes only their own row
create policy profiles_own on public.profiles for all to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- Everything is closed to anon and public by default. Guests reach data only through the functions below.
revoke all on public.profiles, public.invites, public.reports from anon;

-- invites: the host reads and writes their own. Guests use get_invite(id).
create policy invites_host_read on public.invites for select to authenticated using (host_id = auth.uid());
create policy invites_host_insert on public.invites for insert to authenticated with check (host_id = auth.uid());
create policy invites_host_update on public.invites for update to authenticated
  using (host_id = auth.uid()) with check (host_id = auth.uid());
create policy invites_host_delete on public.invites for delete to authenticated using (host_id = auth.uid());

-- responses: anon has no direct access. Guests write through respond() and read through invite_public_summary().
-- Column grants: nobody reads guest_token directly and the host can edit only paid, or delete a row.
revoke all on public.responses from anon, authenticated;
grant select (id, invite_id, name, user_id, rsvp, paid) on public.responses to authenticated;
grant update (paid) on public.responses to authenticated;
grant delete on public.responses to authenticated;
create policy responses_host_read on public.responses for select to authenticated
  using (exists (select 1 from public.invites i where i.id = invite_id and i.host_id = auth.uid()));
create policy responses_own_read on public.responses for select to authenticated using (user_id = auth.uid());
create policy responses_host_paid on public.responses for update to authenticated
  using (exists (select 1 from public.invites i where i.id = invite_id and i.host_id = auth.uid()))
  with check (exists (select 1 from public.invites i where i.id = invite_id and i.host_id = auth.uid()));
create policy responses_host_delete on public.responses for delete to authenticated
  using (exists (select 1 from public.invites i where i.id = invite_id and i.host_id = auth.uid()));

-- messages: no direct inserts or edits. Guests use invite_messages() and post_message(); the host also reads their invites'
-- messages directly (for realtime), without guest_token, and can delete them.
revoke all on public.messages from anon, authenticated;
grant select (id, invite_id, name, user_id, body, created_at) on public.messages to authenticated;
grant delete on public.messages to authenticated;
create policy messages_host_read on public.messages for select to authenticated
  using (exists (select 1 from public.invites i where i.id = invite_id and i.host_id = auth.uid()));
create policy messages_host_delete on public.messages for delete to authenticated
  using (exists (select 1 from public.invites i where i.id = invite_id and i.host_id = auth.uid()));

-- reports: write-only for clients; read them in the dashboard
revoke all on public.reports from authenticated;
grant insert on public.reports to anon, authenticated;
create policy reports_insert on public.reports for insert to anon, authenticated with check (true);

-- Guests and signed-in users answer here. Returns the stored row, including its id. A null paid keeps the old value.
create function public.respond(invite_id uuid, guest_token text, name text, rsvp text, paid boolean default null)
returns public.responses
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  result public.responses;
begin
  if uid is not null then
    insert into public.responses as t (invite_id, user_id, name, rsvp, paid)
    values (respond.invite_id, uid, respond.name, respond.rsvp, coalesce(respond.paid, false))
    on conflict on constraint responses_user_unique
    do update set name = excluded.name, rsvp = excluded.rsvp, paid = coalesce(respond.paid, t.paid)
    returning * into result;
  else
    if respond.guest_token is null or length(respond.guest_token) < 16 then
      raise exception 'guest_token must be at least 16 characters';
    end if;
    insert into public.responses as t (invite_id, guest_token, name, rsvp, paid)
    values (respond.invite_id, respond.guest_token, respond.name, respond.rsvp, coalesce(respond.paid, false))
    on conflict on constraint responses_guest_unique
    do update set name = excluded.name, rsvp = excluded.rsvp, paid = coalesce(respond.paid, t.paid)
    returning * into result;
  end if;
  return result;
end;
$$;

-- What guests see: names, rsvps, totals, the host's payment handles. Never per-person paid.
-- goal = price * (going + host), raised = price * (paid and going + host). Same as DavatKit summarize.
create function public.invite_public_summary(invite_id uuid)
returns table (guests jsonb, going_count int, goal_cents bigint, raised_cents bigint, host_venmo text, host_cashtag text)
language sql stable security definer set search_path = ''
as $$
  select
    coalesce((select jsonb_agg(jsonb_build_object('name', r.name, 'rsvp', r.rsvp) order by r.name, r.id)
              from public.responses r where r.invite_id = i.id), '[]'::jsonb),
    c.going,
    case when i.price_cents is null then null
         else i.price_cents::bigint * (c.going + case when i.host_pays then 1 else 0 end) end,
    case when i.price_cents is null then null
         else i.price_cents::bigint * (c.paid_going + case when i.host_pays then 1 else 0 end) end,
    p.venmo,
    p.cashtag
  from public.invites i
  cross join lateral (
    select count(*) filter (where r.rsvp = 'going')::int as going,
           count(*) filter (where r.rsvp = 'going' and r.paid)::int as paid_going
    from public.responses r where r.invite_id = i.id
  ) c
  left join public.profiles p on p.id = i.host_id
  where i.id = invite_public_summary.invite_id;
$$;

-- Account deletion. Cascades to the user's profile, invites, responses and messages.
create function public.delete_me() returns void
language sql security definer set search_path = ''
as $$ delete from auth.users where id = auth.uid(); $$;

-- One invite by id, for guests. The uuid is the secret.
create function public.get_invite(invite_id uuid) returns setof public.invites
language sql stable security definer set search_path = ''
as $$ select i.* from public.invites i where i.id = get_invite.invite_id; $$;

-- Chat. A message never exposes guest_token.
create type public.chat_message as (id uuid, invite_id uuid, name text, user_id uuid, body text, created_at timestamptz);

create function public.invite_messages(invite_id uuid) returns setof public.chat_message
language sql stable security definer set search_path = ''
as $$
  select m.id, m.invite_id, m.name, m.user_id, m.body, m.created_at
  from public.messages m where m.invite_id = invite_messages.invite_id order by m.created_at, m.id;
$$;

-- user_id is always the caller (null for guests), so nobody can post as someone else.
create function public.post_message(invite_id uuid, name text, guest_token text, body text) returns public.chat_message
language sql security definer set search_path = ''
as $$
  insert into public.messages as m (invite_id, name, user_id, guest_token, body)
  values (post_message.invite_id, post_message.name, auth.uid(), post_message.guest_token, post_message.body)
  returning m.id, m.invite_id, m.name, m.user_id, m.body, m.created_at;
$$;

-- New functions are executable by anon by default, so revoke explicitly, then grant.
revoke execute on function public.respond, public.invite_public_summary, public.delete_me, public.get_invite,
  public.invite_messages, public.post_message from public, anon, authenticated;
grant execute on function public.respond, public.invite_public_summary, public.get_invite,
  public.invite_messages, public.post_message to anon, authenticated;
grant execute on function public.delete_me to authenticated;

-- Keep updated_at honest on every edit
create function public.touch_updated_at() returns trigger language plpgsql set search_path = ''
as $$ begin new.updated_at = now(); return new; end; $$;
create trigger invites_touch before update on public.invites
  for each row execute function public.touch_updated_at();

-- Posters: public download by URL, signed-in users write only under <uid>/
insert into storage.buckets (id, name, public) values ('posters', 'posters', true) on conflict (id) do nothing;

-- No list access for anon: public bucket URLs download without a select policy. Owners can list their own folder.
create policy posters_read on storage.objects for select to authenticated
  using (bucket_id = 'posters' and (storage.foldername(name))[1] = auth.uid()::text);
create policy posters_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'posters' and (storage.foldername(name))[1] = auth.uid()::text);
create policy posters_update on storage.objects for update to authenticated
  using (bucket_id = 'posters' and (storage.foldername(name))[1] = auth.uid()::text);
create policy posters_delete on storage.objects for delete to authenticated
  using (bucket_id = 'posters' and (storage.foldername(name))[1] = auth.uid()::text);

-- Realtime (host sees responses live; everyone sees messages live)
alter publication supabase_realtime add table public.responses, public.messages;
