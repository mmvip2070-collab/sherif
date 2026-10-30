-- LOQTA | لقطة: Supabase schema (Postgres)
-- Run in Supabase > SQL Editor. Currency is EGP (جنيه) everywhere.

-- 1. Categories with per-category commission
create table categories (
  id uuid default gen_random_uuid() primary key,
  name_ar text not null unique,
  name_en text,
  commission int not null check (commission between 0 and 100),
  icon text,
  sort int default 0
);

insert into categories (name_ar, name_en, commission, icon, sort) values
('إكسسوارات موبايل', 'Mobile accessories', 10, '📱', 1),
('أحذية',            'Shoes',              15, '👟', 2),
('إلكترونيات',       'Electronics',        12, '🎧', 3),
('موضة',             'Fashion',            15, '👜', 4),
('منزل ومطبخ',       'Home & kitchen',     10, '🏠', 5),  -- commission assumed, edit it
('جمال وعناية',      'Beauty & care',      10, '💄', 6);  -- commission assumed, edit it

-- 2. Profiles: customers, merchants, admin (linked to Supabase Auth, phone login)
create table profiles (
  id uuid primary key references auth.users on delete cascade,
  role text not null default 'customer' check (role in ('customer','merchant','admin')),
  full_name text,
  phone text,
  store_name text,
  whatsapp text,                       -- international form, e.g. 201018881501
  status text not null default 'approved' check (status in ('pending','approved','suspended')),
  created_at timestamptz default now()
);

create or replace function is_admin() returns boolean
language sql security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin');
$$;

-- New signups become customers; merchants start as pending until you approve them
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, phone) values (new.id, new.phone);
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

-- 3. Products
create table products (
  id uuid default gen_random_uuid() primary key,
  merchant_id uuid not null references profiles(id),
  category_id uuid not null references categories(id),
  name text not null,
  description text,
  price_before numeric(10,2) not null check (price_before > 0),
  price_after numeric(10,2) not null check (price_after > 0),
  stock int not null default 0 check (stock >= 0),
  images text[] default '{}',
  is_today_deal boolean default false,      -- "لقطة اليوم"
  status text not null default 'pending' check (status in ('draft','pending','active','hidden')),
  created_at timestamptz default now(),
  check (price_after < price_before)
);
create index on products (category_id, status);

-- 4. Shipping companies
create table shipping_companies (
  id uuid default gen_random_uuid() primary key,
  name text not null unique,
  active boolean default true,
  api_ref text
);
insert into shipping_companies (name) values ('Bosta'), ('Mylerz');

-- 5. Coupons
create table coupons (
  id uuid default gen_random_uuid() primary key,
  code text not null unique,
  percent int not null check (percent between 1 and 100),
  active boolean default true,
  expires_at timestamptz,
  max_uses int,
  used int not null default 0
);
insert into coupons (code, percent) values ('LOQTA10', 10);

-- 6. Orders and items
create table orders (
  id bigint generated always as identity primary key,
  customer_id uuid references profiles(id),
  customer_name text not null,
  phone text not null,
  city text,
  address text not null,
  payment_method text not null default 'cod' check (payment_method in ('cod','paymob','fawry')),
  payment_status text not null default 'pending' check (payment_status in ('pending','paid','failed')),
  shipping_company_id uuid references shipping_companies(id),
  shipping_status text not null default 'new' check (shipping_status in ('new','packed','shipped','delivered','returned','cancelled')),
  coupon_id uuid references coupons(id),
  subtotal numeric(10,2) not null,
  discount numeric(10,2) not null default 0,
  shipping_fee numeric(10,2) not null default 0,
  total numeric(10,2) not null,
  created_at timestamptz default now()
);

create table order_items (
  id uuid default gen_random_uuid() primary key,
  order_id bigint not null references orders(id) on delete cascade,
  product_id uuid references products(id),
  merchant_id uuid references profiles(id),
  name text not null,
  qty int not null check (qty > 0),
  unit_price numeric(10,2) not null,
  commission_pct int not null,                       -- copied from the category at order time
  commission_amount numeric(10,2) generated always as (round(unit_price * qty * commission_pct / 100, 2)) stored
);

-- 7. Paid ads: merchant pays to appear first
create table ads (
  id uuid default gen_random_uuid() primary key,
  product_id uuid not null references products(id) on delete cascade,
  merchant_id uuid not null references profiles(id),
  amount_paid numeric(10,2) not null default 0,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'pending' check (status in ('pending','active','ended'))
);

-- 8. Admin dashboard numbers
create view admin_stats as
select
  coalesce(sum(o.total) filter (where o.shipping_status <> 'cancelled'), 0) as total_sales,
  count(o.id) as orders_count,
  (select count(*) from products) as products_count,
  (select coalesce(sum(commission_amount), 0) from order_items) as my_commission
from orders o;

-- 9. Row Level Security
alter table categories enable row level security;
alter table profiles enable row level security;
alter table products enable row level security;
alter table shipping_companies enable row level security;
alter table coupons enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;
alter table ads enable row level security;

create policy "categories read" on categories for select using (true);
create policy "categories admin" on categories for all using (is_admin()) with check (is_admin());

create policy "profile own read" on profiles for select using (id = auth.uid() or is_admin());
create policy "profile own update" on profiles for update using (id = auth.uid()) with check (id = auth.uid() and role = (select role from profiles where id = auth.uid()));
create policy "profile admin" on profiles for all using (is_admin()) with check (is_admin());

create policy "products public" on products for select using (status = 'active' or merchant_id = auth.uid() or is_admin());
create policy "products merchant insert" on products for insert with check (
  merchant_id = auth.uid() and exists (select 1 from profiles where id = auth.uid() and role = 'merchant' and status = 'approved'));
create policy "products merchant update" on products for update using (merchant_id = auth.uid()) with check (merchant_id = auth.uid() and status in ('draft','pending','hidden'));
create policy "products admin" on products for all using (is_admin()) with check (is_admin());

create policy "orders own" on orders for select using (customer_id = auth.uid() or is_admin());
create policy "orders insert" on orders for insert with check (customer_id = auth.uid());
create policy "orders admin" on orders for all using (is_admin()) with check (is_admin());

create policy "items visible" on order_items for select using (
  merchant_id = auth.uid() or is_admin()
  or exists (select 1 from orders o where o.id = order_id and o.customer_id = auth.uid()));
create policy "items admin" on order_items for all using (is_admin()) with check (is_admin());

create policy "shipping admin" on shipping_companies for all using (is_admin()) with check (is_admin());
create policy "coupons admin" on coupons for all using (is_admin()) with check (is_admin());

create policy "ads merchant read" on ads for select using (merchant_id = auth.uid() or is_admin());
create policy "ads merchant insert" on ads for insert with check (merchant_id = auth.uid());
create policy "ads admin" on ads for all using (is_admin()) with check (is_admin());

-- After you sign up once with your phone, make yourself admin:
-- update profiles set role = 'admin' where phone = '201018881501';
