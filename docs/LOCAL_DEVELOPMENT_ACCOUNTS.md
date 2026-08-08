# Local Development Accounts & Credentials

> **WARNING**: These credentials are strictly for **local development and testing** against the local Supabase container. **NEVER** use these credentials in production environments or hardcode credentials into production Flutter app binaries.

All local development accounts are seeded deterministically via `supabase/seed.sql`.

---

## Standard Password for All Development Accounts

`Password123!`

---

## Seeded Development Accounts Matrix

| Role | Email Address | Password | Profile Name | Primary Branch | Domain Record |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Super Admin** | `superadmin@academy.com` | `Password123!` | Super Admin User | Main Campus | N/A |
| **Branch Admin** | `admin@academy.com` | `Password123!` | Branch Admin User | Main Campus | N/A |
| **Operations Staff** | `staff@academy.com` | `Password123!` | Operations Staff User | Main Campus | N/A |
| **Educator / Teacher** | `teacher@academy.com` | `Password123!` | Educator Teacher User | Main Campus | Teacher Record (`7000...0001`) |
| **Guardian / Parent** | `parent@academy.com` | `Password123!` | Guardian Parent User | Main Campus | Parent Record (`8000...0001`) |
| **Learner / Student** | `student@academy.com` | `Password123!` | Learner Student User | Main Campus | Student Record (`9000...0001`, `STU-2026-0001`) |

---

## Account Verification & Portal Matrix

1. **Admin Web Dashboard**: Accessible by `superadmin@academy.com` & `admin@academy.com`. Other roles produce `Portal Access Denied`.
2. **Operations Staff App**: Accessible by `staff@academy.com`, `admin@academy.com`, & `superadmin@academy.com`.
3. **Teacher Educator App**: Accessible by `teacher@academy.com`, `admin@academy.com`, & `superadmin@academy.com`.
4. **Student Learning App**: Accessible by `student@academy.com`.
5. **Parent Guardian App**: Accessible by `parent@academy.com`. Linked to student `student@academy.com`.

---

## Resetting Local Database & Seed Data

To reset local database and re-seed all test accounts:

```bash
npx supabase db reset
```
