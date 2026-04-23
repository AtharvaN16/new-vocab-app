-- 1. Create words table
create table words (
  id uuid primary key default gen_random_uuid(),
  word text not null,
  phonetic text,
  definitions jsonb,
  examples jsonb,
  synonyms text[],
  antonyms text[],
  etymology text,
  otherForms jsonb,
  ai_mnemonic text,
  user_notes text,
  sources text[],
  user_id uuid references auth.users(id) default auth.uid(),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Create srs_cards table
create table srs_cards (
  id uuid primary key default gen_random_uuid(),
  word_id uuid references words(id) on delete cascade,
  due timestamp with time zone not null,
  stability float8 not null,
  difficulty float8 not null,
  elapsed_days int4 not null,
  scheduled_days int4 not null,
  reps int4 not null,
  lapses int4 not null,
  state text not null,
  last_review timestamp with time zone,
  user_id uuid references auth.users(id) default auth.uid(),
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 3. Create collections table
create table collections (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  color_hex text,
  is_public boolean default false,
  word_ids uuid[] default '{}',
  user_id uuid references auth.users(id) default auth.uid(),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable Row Level Security (RLS)
alter table words enable row level security;
alter table srs_cards enable row level security;
alter table collections enable row level security;

-- Create Policies (Only owner can see/edit)
create policy "Users can only access their own words" on words for all using (auth.uid() = user_id);
create policy "Users can only access their own cards" on srs_cards for all using (auth.uid() = user_id);
create policy "Users can only access their own collections" on collections for all using (auth.uid() = user_id);
