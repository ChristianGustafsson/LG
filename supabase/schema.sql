-- Ledningsgruppstest: "Är vi ett verkligt team?"
-- Kör hela filen en gång i Supabase: SQL Editor -> New query -> klistra in -> Run.
--
-- Säkerhetsmodell:
--  * Tabellerna har Row Level Security påslaget utan policyer, så den publika
--    (anon) nyckeln kan inte läsa eller skriva tabellerna direkt.
--  * All åtkomst sker via funktionerna nedan (security definer), som kontrollerar
--    gruppens id, deltagarens hemliga token eller vd:ns admin-nyckel.
--  * Deltagarnas namn returneras bara till den som har admin-nyckeln.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.groups (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(name) between 1 and 120),
  admin_key   text not null default encode(extensions.gen_random_bytes(18), 'hex'),
  round_name  text,
  created_at  timestamptz not null default now()
);

create table if not exists public.responses (
  id            bigserial primary key,
  group_id      uuid not null references public.groups(id) on delete cascade,
  token         text not null check (char_length(token) between 20 and 100),
  name          text check (char_length(name) <= 80),
  answers       int[] not null check (cardinality(answers) = 8 and answers <@ array[0,1,2]),
  mission       text check (char_length(mission) <= 1200),
  comment       text check (char_length(comment) <= 1200),
  submitted_at  timestamptz not null default now(),
  unique (group_id, token)
);

create table if not exists public.round_history (
  id          bigserial primary key,
  group_id    uuid not null references public.groups(id) on delete cascade,
  name        text,
  n           int,
  avg         numeric(4,1),
  levels      int[],
  created_at  timestamptz not null default now()
);

alter table public.groups        enable row level security;
alter table public.responses     enable row level security;
alter table public.round_history enable row level security;
revoke all on public.groups, public.responses, public.round_history from anon, authenticated;

-- Skapa en ny grupp. Returnerar gruppens id och vd:ns admin-nyckel.
create or replace function public.create_group(p_name text)
returns table (group_id uuid, admin_key text)
language plpgsql security definer set search_path = public, extensions as $$
begin
  return query
    insert into groups (name, round_name)
    values (left(trim(p_name), 120), to_char(now(), 'YYYY-MM-DD'))
    returning groups.id, groups.admin_key;
end $$;

-- Grundinfo om gruppen (namn, omgång, antal svar).
create or replace function public.get_group(p_group uuid)
returns table (name text, round_name text, n int)
language sql security definer set search_path = public stable as $$
  select g.name, g.round_name,
         (select count(*)::int from responses r where r.group_id = g.id)
  from groups g where g.id = p_group;
$$;

-- Skicka in eller uppdatera sina svar.
create or replace function public.submit_response(
  p_group uuid, p_token text, p_name text, p_answers int[], p_mission text, p_comment text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from groups where id = p_group) then
    raise exception 'Okänd grupp';
  end if;
  insert into responses (group_id, token, name, answers, mission, comment, submitted_at)
  values (p_group, p_token, nullif(left(trim(p_name), 80), ''), p_answers,
          left(coalesce(p_mission, ''), 1200), left(coalesce(p_comment, ''), 1200), now())
  on conflict (group_id, token) do update
    set name = excluded.name, answers = excluded.answers, mission = excluded.mission,
        comment = excluded.comment, submitted_at = now();
end $$;

-- Hämta sina egna tidigare svar.
create or replace function public.get_my_response(p_group uuid, p_token text)
returns table (name text, answers int[], mission text, comment text)
language sql security definer set search_path = public stable as $$
  select r.name, r.answers, r.mission, r.comment
  from responses r where r.group_id = p_group and r.token = p_token;
$$;

-- Alla svar utan namn. Kräver att man själv har svarat, eller admin-nyckeln.
create or replace function public.get_results(p_group uuid, p_token text)
returns table (answers int[], mission text, comment text)
language sql security definer set search_path = public stable as $$
  select r.answers, r.mission, r.comment
  from responses r
  where r.group_id = p_group
    and (
      exists (select 1 from responses m where m.group_id = p_group and m.token = p_token)
      or exists (select 1 from groups g where g.id = p_group and g.admin_key = p_token)
    )
  order by md5(r.token);
$$;

-- Vd:ns vy: vilka som har svarat (namn, inte svar).
create or replace function public.get_admin(p_group uuid, p_key text)
returns table (name text, submitted_at timestamptz)
language sql security definer set search_path = public stable as $$
  select coalesce(r.name, 'Utan namn'), r.submitted_at
  from responses r join groups g on g.id = r.group_id
  where g.id = p_group and g.admin_key = p_key
  order by r.submitted_at;
$$;

-- Kontrollera admin-nyckeln.
create or replace function public.check_admin(p_group uuid, p_key text)
returns boolean
language sql security definer set search_path = public stable as $$
  select exists (select 1 from groups where id = p_group and admin_key = p_key);
$$;

-- Starta ny omgång: spara sammanfattningen och rensa svaren.
create or replace function public.new_round(
  p_group uuid, p_key text, p_new_name text, p_n int, p_avg numeric, p_levels int[])
returns void
language plpgsql security definer set search_path = public as $$
declare v_old text;
begin
  select round_name into v_old from groups where id = p_group and admin_key = p_key;
  if not found then raise exception 'Fel admin-nyckel'; end if;
  if coalesce(p_n, 0) > 0 then
    insert into round_history (group_id, name, n, avg, levels)
    values (p_group, v_old, p_n, p_avg, p_levels);
  end if;
  delete from responses where group_id = p_group;
  update groups set round_name = nullif(left(trim(p_new_name), 60), '') where id = p_group;
end $$;

-- Tidigare omgångar.
create or replace function public.get_history(p_group uuid)
returns table (name text, n int, avg numeric, levels int[], created_at timestamptz)
language sql security definer set search_path = public stable as $$
  select h.name, h.n, h.avg, h.levels, h.created_at
  from round_history h where h.group_id = p_group order by h.created_at desc;
$$;

revoke execute on function
  public.create_group(text),
  public.get_group(uuid),
  public.submit_response(uuid, text, text, int[], text, text),
  public.get_my_response(uuid, text),
  public.get_results(uuid, text),
  public.get_admin(uuid, text),
  public.check_admin(uuid, text),
  public.new_round(uuid, text, text, int, numeric, int[]),
  public.get_history(uuid)
from public;

grant execute on function
  public.create_group(text),
  public.get_group(uuid),
  public.submit_response(uuid, text, text, int[], text, text),
  public.get_my_response(uuid, text),
  public.get_results(uuid, text),
  public.get_admin(uuid, text),
  public.check_admin(uuid, text),
  public.new_round(uuid, text, text, int, numeric, int[]),
  public.get_history(uuid)
to anon, authenticated;
