-- Run in the Supabase SQL editor after 0001_init.sql. Rolls back; any failed assert raises an error.
begin;

insert into auth.users (id) values
  ('00000000-0000-0000-0000-0000000000a1'), -- host
  ('00000000-0000-0000-0000-0000000000a2'); -- another signed-in user
insert into public.profiles (id, venmo, cashtag) values ('00000000-0000-0000-0000-0000000000a1', 'hostv', 'hostc');
insert into public.invites (id, host_id, title, design, price_cents, host_pays)
  values ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', 't', '{}', 2000, true);

-- anon ---------------------------------------------------------------
set local role anon;

do $$
declare
  inv constant uuid := '00000000-0000-0000-0000-0000000000b1';
  n int;
  s record;
begin
  perform public.respond(inv, 'token-aaaaaaaaaaaaaaaa', 'A', 'going', true);
  perform public.respond(inv, 'token-bbbbbbbbbbbbbbbb', 'B', 'going', false);
  perform public.respond(inv, 'token-cccccccccccccccc', 'C', 'maybe', true);
  perform public.respond(inv, 'token-bbbbbbbbbbbbbbbb', 'B2', 'going', null); -- same token updates, no duplicate

  -- no direct reads of responses, invites, messages, reports (denied or zero rows)
  begin select count(*) into n from public.responses; assert n = 0, 'anon read responses';
  exception when insufficient_privilege then null; end;
  begin select count(*) into n from public.invites; assert n = 0, 'anon listed invites';
  exception when insufficient_privilege then null; end;
  begin select count(*) into n from public.messages; assert n = 0, 'anon listed messages';
  exception when insufficient_privilege then null; end;
  begin select count(*) into n from public.reports; assert n = 0, 'anon read reports';
  exception when insufficient_privilege then null; end;

  -- but one invite by id works
  select count(*) into n from public.get_invite(inv);
  assert n = 1, 'get_invite';

  -- summary: 2 going, goal 2000*(2+1), raised 2000*(1+1)
  select * into s from public.invite_public_summary(inv);
  assert s.going_count = 2, 'going_count';
  assert s.goal_cents = 6000, 'goal_cents';
  assert s.raised_cents = 4000, 'raised_cents';
  assert jsonb_array_length(s.guests) = 3, 'guest rows';
  assert s.host_venmo = 'hostv' and s.host_cashtag = 'hostc', 'host handles';
  assert not (s.guests::text like '%paid%'), 'guests leak paid';
  assert not exists (select 1 from pg_proc p where p.proname = 'invite_public_summary'
                     and 'paid' = any (p.proargnames)), 'summary has a paid column';

  -- short guest token is refused
  begin perform public.respond(inv, 'short', 'X', 'going', false); assert false, 'short token accepted';
  exception when raise_exception then null; end;

  -- chat through the functions only
  perform public.post_message(inv, 'A', 'token-aaaaaaaaaaaaaaaa', 'hi');
  assert (select count(*) from public.invite_messages(inv)) = 1, 'invite_messages';
  assert not exists (select 1 from pg_attribute a where a.attrelid = (select typrelid from pg_type where oid = 'public.chat_message'::regtype)
                     and a.attname = 'guest_token'), 'chat_message exposes guest_token';
  assert (select user_id from public.invite_messages(inv)) is null, 'guest message has user_id';
  begin perform public.post_message(inv, 'A', null, ''); assert false, 'empty body accepted';
  exception when check_violation then null; end;
  begin perform public.post_message(inv, 'A', null, repeat('x', 1001)); assert false, 'long body accepted';
  exception when check_violation then null; end;
  begin perform public.post_message(inv, '', null, 'x'); assert false, 'empty name accepted';
  exception when check_violation then null; end;
  begin insert into public.messages (invite_id, name, body) values (inv, 'A', 'direct'); assert false, 'anon inserted a message';
  exception when insufficient_privilege then null; end;

  -- no invite writes, no response edits
  begin insert into public.invites (host_id, design) values ('00000000-0000-0000-0000-0000000000a1', '{}');
    assert false, 'anon created an invite';
  exception when insufficient_privilege then null; end;
  begin update public.responses set paid = true; assert false, 'anon updated responses';
  exception when insufficient_privilege then null; end;
  begin delete from public.responses; assert false, 'anon deleted responses';
  exception when insufficient_privilege then null; end;
  begin delete from public.messages; assert false, 'anon deleted messages';
  exception when insufficient_privilege then null; end;

  -- reports are write-only
  insert into public.reports (invite_id, reason) values (inv, 'spam');

  -- delete_me is not callable by anon
  begin perform public.delete_me(); assert false, 'anon called delete_me';
  exception when insufficient_privilege then null; end;
end $$;

reset role;

-- another signed-in user (not the host) ---------------------------------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}', true);

do $$
declare
  inv constant uuid := '00000000-0000-0000-0000-0000000000b1';
  n int;
  r public.responses;
begin
  assert (select count(*) from public.responses) = 0, 'non-host read responses';
  assert (select count(*) from public.invites) = 0, 'non-host read invites';
  assert (select count(*) from public.messages) = 0, 'non-host read messages';
  update public.responses set paid = true;
  get diagnostics n = row_count;
  assert n = 0, 'non-host updated responses';
  delete from public.messages where invite_id = inv;
  get diagnostics n = row_count;
  assert n = 0, 'non-host deleted messages';

  -- respond always targets the caller
  r := public.respond(inv, 'ignored-token-aaaaaaaa', 'U2', 'going', true);
  assert r.user_id = '00000000-0000-0000-0000-0000000000a2', 'respond targeted another user';
  -- null paid keeps the old value
  r := public.respond(inv, null, 'U2 renamed', 'maybe', null);
  assert r.paid and r.name = 'U2 renamed' and r.rsvp = 'maybe', 'paid not preserved';
  assert (select count(*) from public.responses) = 1, 'sees only own response';
  delete from public.responses where invite_id = inv; -- RLS also hides the others' rows from delete
  get diagnostics n = row_count;
  assert n = 0, 'non-host deleted responses';
  begin perform public.post_message(inv, 'U2', null, 'hello'); end;
  assert (select user_id from public.invite_messages(inv) where body = 'hello')
         = '00000000-0000-0000-0000-0000000000a2', 'post_message user_id';
end $$;

reset role;

-- the host ----------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);

do $$
declare
  inv constant uuid := '00000000-0000-0000-0000-0000000000b1';
  n int;
  rid uuid;
  tok text;
begin
  assert (select count(*) from public.responses) = 4, 'host reads responses';
  assert (select count(*) from public.invites) = 1, 'host reads invite';
  assert (select count(*) from public.messages) = 2, 'host reads messages';
  update public.responses set paid = false where name = 'A';
  get diagnostics n = row_count;
  assert n = 1, 'host updates paid';
  begin update public.responses set name = 'x'; assert false, 'host edited name';
  exception when insufficient_privilege then null; end;
  begin update public.responses set rsvp = 'cant'; assert false, 'host edited rsvp';
  exception when insufficient_privilege then null; end;
  begin perform guest_token from public.responses; assert false, 'host read guest_token';
  exception when insufficient_privilege then null; end;
  begin perform guest_token from public.messages; assert false, 'host read message guest_token';
  exception when insufficient_privilege then null; end;

  -- setPaid sends return=minimal; returning a readable column also works, guest_token does not
  update public.responses set paid = true where name = 'A' returning id into rid;
  assert rid is not null, 'host update returning id';
  begin update public.responses set paid = true where name = 'A' returning guest_token into tok;
    assert false, 'host update returned guest_token';
  exception when insufficient_privilege then null; end;

  -- moderation: the host deletes a message and a response on their invite
  delete from public.messages where invite_id = inv and body = 'hi';
  get diagnostics n = row_count;
  assert n = 1, 'host deletes a message';
  delete from public.responses where invite_id = inv and name = 'C';
  get diagnostics n = row_count;
  assert n = 1, 'host deletes a response';

  -- an upsert that sends nulls clears the fundraiser, start time and poster
  update public.invites set poster_path = '00000000-0000-0000-0000-0000000000a1/00000000-0000-0000-0000-0000000000b1.png',
    starts_at = now() where id = inv;
  insert into public.invites as t (id, host_id, title, design, starts_at, poster_path, price_cents, host_pays, time_zone)
    values (inv, '00000000-0000-0000-0000-0000000000a1', 't', '{}', null, null, null, false, 'America/Chicago')
    on conflict (id) do update set starts_at = excluded.starts_at, poster_path = excluded.poster_path,
      price_cents = excluded.price_cents, host_pays = excluded.host_pays, time_zone = excluded.time_zone;
  assert (select price_cents is null and starts_at is null and poster_path is null and time_zone = 'America/Chicago'
          from public.invites where id = inv), 'upsert with nulls did not clear';

  -- poster_path must be <uuid>/<uuid>.png in lowercase
  begin update public.invites set poster_path = '../x.png' where id = inv; assert false, 'bad poster_path accepted';
  exception when check_violation then null; end;
  begin update public.invites set poster_path = upper('00000000-0000-0000-0000-0000000000a1/00000000-0000-0000-0000-0000000000b1') || '.png'
    where id = inv; assert false, 'uppercase poster_path accepted';
  exception when check_violation then null; end;
end $$;

rollback;
