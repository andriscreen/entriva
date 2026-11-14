# Project Context: Smart Campus Guest & Logistics Management System

## System Overview
- **Project Name**: Plant Access Portal (Smart Campus Guest & Logistics Management System)
- **Target Facilities**: Multi-plant industrial facility in Jatake (Jatake 1, Jatake 2, Jatake 3, and Jatake 6).
- **Core Capabilities**: Driver queue management, warehouse dock assignment, real-time Digital Twin map tracking, visitor invitations, mess room allocation, OpenWA WhatsApp gateway messaging, and MikroTik RADIUS WiFi voucher pool.

---

## Monorepo Architecture & Tech Stack

### 1. Frontend: Nuxt 3 (`apps/frontend`)
- **Framework**: Nuxt 3 with TypeScript & Vue 3 Composition API (`<script setup lang="ts">`).
- **UI & Styling**: `shadcn-vue`(Zinc dark theme).
- **Typography**: DM Sans (sans-serif) & JetBrains Mono (monospace via `@nuxt/fonts`).
- **Icons**: `lucide-vue-next`.
- **Database & Auth Client**: `@nuxtjs/supabase` module (`useSupabaseClient()`, `useSupabaseUser()`).
- **Routing Protection**: `middleware/auth.global.ts` for automated 6-role routing.

### 2. Backend: Node.js Express (`apps/backend`)
- **WhatsApp Gateway**: `@open-wa/wa-automate` (OpenWA Engine) for gate QR tickets, notifications, and dock pager.
- **WiFi Provisioning**: MikroTik RouterOS API wrapper.

### 3. Database: Supabase PostgreSQL (`supabase/`)
- The frontend connects through `@nuxtjs/supabase`; local connection settings belong in `apps/frontend/.env`.
- Schema and sample data are tracked in `supabase/migrations/00001_initial_schema.sql` and `supabase/migrations/00002_seed_data.sql`.

---

## 6 Operational Roles & Dynamic Routing Matrix

| Role Key | Role Name | Primary Route Path | Scope & Responsibilities |
| :--- | :--- | :--- | :--- |
| `super_admin` | Super Admin System | `/dashboard/super-admin` | Multi-plant system config, node editor, global audit |
| `admin_logistics` | Admin Logistik | `/dashboard/admin-logistics` | Vendor management, driver approval queue, dock setup |
| `operator_logistics` | Operator Yard | `/dashboard/operator` | Command Center, Digital Twin real-time map, Call to Dock pager |
| `admin_fs` | Admin FS / GA | `/dashboard/admin-fs` | Visitor management overview, mess room assignments |
| `user_paragonian` | User Paragonian (Host) | `/dashboard/user` | Guest invitation creation, personal host schedule |
| `it_support` | IT Support | `/dashboard/it-support` | OpenWA session status, MikroTik WiFi voucher pool |

### Public & Kiosk Routes
- Public Guest Form: `/public/tamu`
- Public Logistics Form: `/public/logistik`
- Gate Scanner Kiosk: `/kiosk/scanner`

---

## AI Coding Standards
1. **Script Setup**: Always use `<script setup lang="ts">`.
2. **Auto-Imports**: Rely on Nuxt 3 auto-imports (`ref`, `computed`, `onMounted`, `useSupabaseClient`, `useSupabaseUser`, `navigateTo`).
3. **Icons**: Import icons explicitly from `lucide-vue-next` (e.g., `import { Truck } from 'lucide-vue-next'`).
4. **Realtime Channels**: Always unsubscribe Supabase channels inside `onUnmounted()`.
5. **Application Data**: Treat the configured Supabase project and its existing records as the source of truth. Check the migrations for the current schema and use the Supabase client instead of adding mock or hardcoded business data.
6. **Database Safety**: Keep credentials out of source control and logs; never expose service-role/secret keys in frontend code. Respect RLS and surface Supabase errors. Do not run database resets or the destructive sample-data migration against a connected shared/hosted project.
7. **Authentication**: Use Supabase Auth for sign-in and sign-out. Read the user's role from `public.profiles`; never accept a role selected or supplied by the client as authorization.