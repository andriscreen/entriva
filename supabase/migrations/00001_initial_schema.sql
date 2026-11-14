-- Reset Schema (Jika Pembuatan Ulang)
DROP TABLE IF EXISTS public.wifi_vouchers CASCADE;
DROP TABLE IF EXISTS public.mess_rooms CASCADE;
DROP TABLE IF EXISTS public.guest_invitations CASCADE;
DROP TABLE IF EXISTS public.logistics_queues CASCADE;
DROP TABLE IF EXISTS public.vendors CASCADE;
DROP TABLE IF EXISTS public.map_nodes CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

DROP TYPE IF EXISTS public.user_role CASCADE;
DROP TYPE IF EXISTS public.logistics_status CASCADE;
DROP TYPE IF EXISTS public.guest_status CASCADE;

-- 1. ENUM DEFINITIONS
CREATE TYPE public.user_role AS ENUM (
  'super_admin',
  'admin_logistics',
  'operator_logistics',
  'admin_fs',
  'user_paragonian',
  'it_support'
);

CREATE TYPE public.logistics_status AS ENUM (
  'pending',
  'approved',
  'waiting_in_yard',
  'called_to_dock',
  'unloading',
  'completed',
  'cancelled'
);

CREATE TYPE public.guest_status AS ENUM (
  'invited',
  'checked_in',
  'completed',
  'cancelled'
);

-- 2. PROFILES TABLE
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  full_name TEXT NOT NULL,
  phone_number TEXT,
  role public.user_role NOT NULL DEFAULT 'user_paragonian',
  plant_location TEXT DEFAULT 'Jatake 1',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. MAP NODES TABLE (Digital Twin Locations)
CREATE TABLE public.map_nodes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  plant_location TEXT NOT NULL DEFAULT 'Jatake 1',
  node_type TEXT NOT NULL CHECK (node_type IN ('gate', 'holding_yard', 'dock', 'mess', 'meeting_room')),
  x_coord INT NOT NULL DEFAULT 0,
  y_coord INT NOT NULL DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. VENDORS TABLE
CREATE TABLE public.vendors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  company_code TEXT UNIQUE,
  contact_person TEXT,
  phone_number TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. LOGISTICS QUEUES TABLE
CREATE TABLE public.logistics_queues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  queue_number TEXT UNIQUE NOT NULL,
  driver_name TEXT NOT NULL,
  driver_phone TEXT NOT NULL,
  license_plate TEXT NOT NULL,
  cargo_type TEXT NOT NULL,
  vendor_id UUID REFERENCES public.vendors(id) ON DELETE SET NULL,
  plant_location TEXT NOT NULL DEFAULT 'Jatake 1',
  status public.logistics_status NOT NULL DEFAULT 'pending',
  current_node_id UUID REFERENCES public.map_nodes(id) ON DELETE SET NULL,
  assigned_dock_id UUID REFERENCES public.map_nodes(id) ON DELETE SET NULL,
  approved_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  unloading_started_at TIMESTAMPTZ
);

-- 6. GUEST INVITATIONS TABLE (GA / FS & Paragonian User)
CREATE TABLE public.guest_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  qr_code TEXT UNIQUE NOT NULL,
  guest_name TEXT NOT NULL,
  guest_company TEXT,
  guest_phone TEXT NOT NULL,
  host_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  visit_date TIMESTAMPTZ NOT NULL,
  purpose TEXT NOT NULL,
  status public.guest_status NOT NULL DEFAULT 'invited',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. MESS ROOMS TABLE
CREATE TABLE public.mess_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_name TEXT NOT NULL,
  plant_location TEXT NOT NULL DEFAULT 'Jatake 1',
  capacity INT DEFAULT 1,
  is_occupied BOOLEAN DEFAULT FALSE,
  current_guest_id UUID REFERENCES public.guest_invitations(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. WIFI VOUCHERS TABLE (IT Support)
CREATE TABLE public.wifi_vouchers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  voucher_code TEXT UNIQUE NOT NULL,
  assigned_guest_id UUID REFERENCES public.guest_invitations(id) ON DELETE SET NULL,
  is_used BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ENABLE ROW LEVEL SECURITY
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.map_nodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logistics_queues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mess_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wifi_vouchers ENABLE ROW LEVEL SECURITY;

-- RLS POLICIES (Full Access for Authenticated Users for Internal Dashboard)
CREATE POLICY "Allow auth users full access to profiles" ON public.profiles FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow auth users full access to map_nodes" ON public.map_nodes FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow auth users full access to vendors" ON public.vendors FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow auth users full access to logistics_queues" ON public.logistics_queues FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow auth users full access to guest_invitations" ON public.guest_invitations FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow auth users full access to mess_rooms" ON public.mess_rooms FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow auth users full access to wifi_vouchers" ON public.wifi_vouchers FOR ALL TO authenticated USING (true);

-- PUBLIC ACCESS FOR GATE SCANNER & REGISTRATION FORMS
CREATE POLICY "Allow anon read queues" ON public.logistics_queues FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon insert queues" ON public.logistics_queues FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow anon read guest invitations" ON public.guest_invitations FOR SELECT TO anon USING (true);