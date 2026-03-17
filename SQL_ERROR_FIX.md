# 🔧 SQL Error Fix - Table Creation Order

## Problem
```
ERROR:  relation "user_mgmt.users" does not exist 
SQL state: 42P01
```

## Root Cause
The `role_permissions` table had a foreign key reference to `user_mgmt.users`:
```sql
REFERENCES user_mgmt.users(user_id)  -- This table didn't exist yet!
```

But the `user_mgmt.users` table was created AFTER `role_permissions`, causing a dependency violation.

## Solution
Reorganized table creation order to respect foreign key dependencies:

### Correct Order (Now Fixed ✅)
```
1. roles                    (no dependencies)
   ↓
2. permissions             (no dependencies)
   ↓
3. users                   (references roles)
   ↓
4. role_permissions        (references users, roles, permissions)
   ↓
5. audit_logs              (references users)
6. login_history           (references users)
7. sessions                (references users)
8. password_reset_tokens   (references users)
```

### What Changed
| Before | After |
|--------|-------|
| roles → permissions → role_permissions → users | roles → permissions → **users** → role_permissions |

## Files Updated
✅ `/Users/prabhakarapelluru/prabhakara/git/dataimpulsetek/health_insurance_saas_datamodels/datamodel1.0/12_schema_user_management.sql`

## Deployment

Now you can safely run:
```bash
psql -U postgres -h 192.168.1.215 -d health_insurance < \
  datamodel1.0/12_schema_user_management.sql
```

## Verification
After successful deployment:
```bash
# Verify all tables exist
psql -U postgres -h 192.168.1.215 -d health_insurance -c "\dt user_mgmt.*"

# Verify demo users created
psql -U postgres -h 192.168.1.215 -d health_insurance -c "SELECT * FROM user_mgmt.users;"

# Verify role permissions assigned
psql -U postgres -h 192.168.1.215 -d health_insurance -c "SELECT * FROM user_mgmt.role_permissions LIMIT 5;"
```

---

**Status**: ✅ FIXED - Ready for deployment
