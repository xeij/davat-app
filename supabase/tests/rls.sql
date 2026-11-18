-- Run in the Supabase SQL editor after 0001_init.sql. Rolls back; any failed assert raises an error.
begin;

insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000a1');
insert into public.profiles (id, venmo, cashtag) values ('00000000-0000-0000-0000-0000000000a1', 'hostv', 'hostc');
insert into public.invites (id, host_id, title, design, price_cents, host_pays)
  values ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', 't', '{}', 2000, true);

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
  perform public.respond(inv, 'token-bbbbbbbbbbbbbbbb', 'B2', 'going', false); -- same token updates, no duplicate

  -- anon cannot read responses directly (denied or zero rows)
  begin
    select count(*) into n from public.responses;
    assert n = 0, 'anon read responses rows';
  exception when insufficient_privilege then null;
  end;

  -- summary: 2 going, goal 2000*(2+1), raised 2000*(1+1)
  select * into s from public.invite_public_summary(inv);
  assert s.going_count = 2, 'going_count';
  assert s.goal_cents = 6000, 'goal_cents';
  assert s.raised_cents = 4000, 'raised_cents';
  assert jsonb_array_length(s.guests) = 3, 'guest rows';
  assert s.host_venmo = 'hostv' and s.host_cashtag = 'hostc', 'host handles';
  assert not (s.guests::text like '%paid%'), 'guests leak paid';

  -- no paid column in the function's output
  assert not exists (
    select 1 from pg_proc p where p.proname = 'invite_public_summary'
      and 'paid' = any (p.proargnames)), 'summary has a paid column';

  -- short guest token is refused
  begin
    perform public.respond(inv, 'short', 'X', 'going', false);
    assert false, 'short token accepted';
  exception when raise_exception then null;
  end;

  -- messages: anyone posts, length is enforced
  insert into public.messages (invite_id, name, body) values (inv, 'A', 'hi');
  begin
    insert into public.messages (invite_id, name, body) values (inv, 'A', '');
    assert false, 'empty body accepted';
  exception when check_violation then null;
  end;
  begin
    insert into public.messages (invite_id, name, body) values (inv, 'A', repeat('x', 1001));
    assert false, 'long body accepted';
  exception when check_violation then null;
  end;
  begin
    insert into public.messages (invite_id, name, user_id, body)
      values (inv, 'A', '00000000-0000-0000-0000-0000000000a1', 'forged');
    assert false, 'anon posted as a user';
  exception when insufficient_privilege then null;
  end;
  select count(*) into n from public.messages;
  assert n = 1, 'anon cannot read messages';

  -- anon cannot write invites or edit responses
  begin
    insert into public.invites (host_id, design) values ('00000000-0000-0000-0000-0000000000a1', '{}');
    assert false, 'anon created an invite';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.responses set paid = true;
    assert false, 'anon updated responses';
  exception when insufficient_privilege then null;
  end;

  -- reports: write-only
  insert into public.reports (invite_id, reason) values (inv, 'spam');
  select count(*) into n from public.reports;
  assert n = 0, 'anon read reports';

  -- delete_me is not callable by anon
  begin
    perform public.delete_me();
    assert false, 'anon called delete_me';
  exception when insufficient_privilege then null;
  end;
end $$;

rollback;
