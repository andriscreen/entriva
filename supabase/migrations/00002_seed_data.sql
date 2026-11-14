-- Clean up existing seed data
DELETE FROM public.wifi_vouchers;
DELETE FROM public.mess_rooms;
DELETE FROM public.guest_invitations;
DELETE FROM public.logistics_queues;
DELETE FROM public.vendors;
DELETE FROM public.map_nodes;
DELETE FROM public.profiles;
DELETE FROM auth.users WHERE email LIKE '%@paragon.id';

-- Enable pgcrypto extension for password hashing if not available
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. AUTH USERS (Supabase Auth Testing Accounts)
-- Password for all accounts: Password123!
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change_token, phone_change, email_change_token_current, reauthentication_token,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES
  ('a1111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'superadmin@paragon.id', crypt('Password123!', gen_salt('bf')), NOW(), '', '', '', '', '', '', '', '', '{"provider":"email","providers":["email"]}', '{"role":"super_admin","full_name":"Super Admin System"}', NOW(), NOW()),
  ('a2222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'logistics@paragon.id', crypt('Password123!', gen_salt('bf')), NOW(), '', '', '', '', '', '', '', '', '{"provider":"email","providers":["email"]}', '{"role":"admin_logistics","full_name":"Budi Logistics Admin"}', NOW(), NOW()),
  ('a3333333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'operator@paragon.id', crypt('Password123!', gen_salt('bf')), NOW(), '', '', '', '', '', '', '', '', '{"provider":"email","providers":["email"]}', '{"role":"operator_logistics","full_name":"Joko Yard Operator"}', NOW(), NOW()),
  ('a4444444-4444-4444-4444-444444444444', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'fs@paragon.id', crypt('Password123!', gen_salt('bf')), NOW(), '', '', '', '', '', '', '', '', '{"provider":"email","providers":["email"]}', '{"role":"admin_fs","full_name":"Siti Admin FS/GA"}', NOW(), NOW()),
  ('a5555555-5555-5555-5555-555555555555', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'paragonian@paragon.id', crypt('Password123!', gen_salt('bf')), NOW(), '', '', '', '', '', '', '', '', '{"provider":"email","providers":["email"]}', '{"role":"user_paragonian","full_name":"Andri Irawan (Host)"}', NOW(), NOW()),
  ('a6666666-6666-6666-6666-666666666666', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'itsupport@paragon.id', crypt('Password123!', gen_salt('bf')), NOW(), '', '', '', '', '', '', '', '', '{"provider":"email","providers":["email"]}', '{"role":"it_support","full_name":"Rian IT Support"}', NOW(), NOW());

-- 2. PUBLIC PROFILES
INSERT INTO public.profiles (id, email, full_name, phone_number, role, plant_location) VALUES
  ('a1111111-1111-1111-1111-111111111111', 'superadmin@paragon.id', 'Super Admin System', '081299990001', 'super_admin', 'Jatake 1'),
  ('a2222222-2222-2222-2222-222222222222', 'logistics@paragon.id', 'Budi Logistics Admin', '081299990002', 'admin_logistics', 'Jatake 1'),
  ('a3333333-3333-3333-3333-333333333333', 'operator@paragon.id', 'Joko Yard Operator', '081299990003', 'operator_logistics', 'Jatake 1'),
  ('a4444444-4444-4444-4444-444444444444', 'fs@paragon.id', 'Siti Admin FS/GA', '081299990004', 'admin_fs', 'Jatake 1'),
  ('a5555555-5555-5555-5555-555555555555', 'paragonian@paragon.id', 'Andri Irawan', '081299990005', 'user_paragonian', 'Jatake 1'),
  ('a6666666-6666-6666-6666-666666666666', 'itsupport@paragon.id', 'Rian IT Support', '081299990006', 'it_support', 'Jatake 1');

-- 3. MAP NODES (Digital Twin Locations for Jatake 1)
INSERT INTO public.map_nodes (id, name, plant_location, node_type, x_coord, y_coord) VALUES
  ('b1111111-1111-1111-1111-111111111111', 'Pos Gerbang Utama', 'Jatake 1', 'gate', 50, 100),
  ('b2222222-2222-2222-2222-222222222222', 'Holding Yard A', 'Jatake 1', 'holding_yard', 200, 100),
  ('b3333333-3333-3333-3333-333333333333', 'Dock Loading 01', 'Jatake 1', 'dock', 400, 50),
  ('b4444444-4444-4444-4444-444444444444', 'Dock Loading 02', 'Jatake 1', 'dock', 400, 150),
  ('b5555555-5555-5555-5555-555555555555', 'Dock Loading 03', 'Jatake 1', 'dock', 400, 250),
  ('b6666666-6666-6666-6666-666666666666', 'Mess Room VIP A', 'Jatake 1', 'mess', 150, 300),
  ('b7777777-7777-7777-7777-777777777777', 'Ruang Rapat Utama', 'Jatake 1', 'meeting_room', 250, 300);

-- 4. VENDORS
INSERT INTO public.vendors (id, name, company_code, contact_person, phone_number) VALUES
  ('c1111111-1111-1111-1111-111111111111', 'PT Trans Cargo Express', 'VND-001', 'Dedi Supriyadi', '081388880001'),
  ('c2222222-2222-2222-2222-222222222222', 'PT Bahan Baku Kemasan', 'VND-002', 'Endang Suherman', '081388880002');

-- 5. LOGISTICS QUEUES
INSERT INTO public.logistics_queues (
  id, queue_number, driver_name, driver_phone, license_plate, cargo_type, vendor_id, plant_location, status, current_node_id, assigned_dock_id
) VALUES
  ('d1111111-1111-1111-1111-111111111111', 'TRK-20261110-001', 'Slamet Widodo', '085711112222', 'B 9876 UZX', 'Bahan Botol Skincare', 'c1111111-1111-1111-1111-111111111111', 'Jatake 1', 'waiting_in_yard', 'b2222222-2222-2222-2222-222222222222', NULL),
  ('d2222222-2222-2222-2222-222222222222', 'TRK-20261110-002', 'Agus Prayitno', '085711113333', 'B 9482 KFX', 'Karton Box Master', 'c2222222-2222-2222-2222-222222222222', 'Jatake 1', 'called_to_dock', 'b3333333-3333-3333-3333-333333333333', 'b3333333-3333-3333-3333-333333333333');

-- 6. GUEST INVITATIONS (Created by User Paragonian)
INSERT INTO public.guest_invitations (
  id, qr_code, guest_name, guest_company, guest_phone, host_id, visit_date, purpose, status
) VALUES
  ('e1111111-1111-1111-1111-111111111111', 'QR-GST-20261110-01', 'Hendra Gunawan', 'PT Automation Systems', '081122334455', 'a5555555-5555-5555-5555-555555555555', NOW() + INTERVAL '1 day', 'Audit Sistem Otomasi Pabrik', 'invited');

-- 7. MESS ROOMS
INSERT INTO public.mess_rooms (id, room_name, plant_location, capacity, is_occupied) VALUES
  ('f1111111-1111-1111-1111-111111111111', 'Mess A-01', 'Jatake 1', 2, FALSE),
  ('f2222222-2222-2222-2222-222222222222', 'Mess A-02', 'Jatake 1', 2, FALSE),
  ('f3333333-3333-3333-3333-333333333333', 'Mess B-01 (VIP)', 'Jatake 2', 1, FALSE);

-- 8. WIFI VOUCHERS (IT Pool)
INSERT INTO public.wifi_vouchers (id, voucher_code, is_used) VALUES
  (gen_random_uuid(), 'PRG-GUEST-8821', FALSE),
  (gen_random_uuid(), 'PRG-GUEST-8822', FALSE),
  (gen_random_uuid(), 'PRG-GUEST-8823', FALSE);