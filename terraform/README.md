# ❄️ Snowflake Infrastructure - Stock Analytics Platform

Complete Terraform configuration provisioning an enterprise-grade Snowflake data warehouse for real-time stock market analytics.

## 🏗️ Infrastructure Components

### **Snowflake Resources Created:**

**Database & Schemas:**
- `STOCK_ANALYTICS` - Main data warehouse
  - `RAW` - Bronze layer (Airbyte ingestion)
  - `STAGING` - Silver layer (dbt staging models)
  - `MARTS` - Gold layer (analytics-ready tables)
  - `DBT_DEV` - Development workspace

**Compute:**
- `ANALYTICS_WH` - XSMALL warehouse
  - Auto-suspend: 60 seconds
  - Auto-resume: Enabled
  - Estimated cost: ~$2/credit-hour

**Service Roles:**
- `AIRBYTE_ROLE` - ETL ingestion (write to RAW)
- `DBT_ROLE` - Transformations (read RAW, write STAGING/MARTS)
- `REPORTING_ROLE` - Read-only access (future use)

**Service Users:**
- `AIRBYTE_USER` - Airbyte service account
- `DBT_USER` - dbt Cloud service account

### **Permission Model (RBAC)**

**Key Innovation: Future Ownership Grants**
```hcl
# Automatically transfers ownership of tables created by AIRBYTE_ROLE
resource "snowflake_grant_ownership" "admin_raw_future_tables_ownership" {
  account_role_name = "ACCOUNTADMIN"
  on {
    future {
      object_type_plural = "TABLES"
      in_schema          = "STOCK_ANALYTICS.RAW"
    }
  }
}
```

**This solves the cross-role ownership problem:**
1. Airbyte creates table → Initially owned by AIRBYTE_ROLE
2. Snowflake automatically transfers ownership → ACCOUNTADMIN
3. Future grants to DBT_ROLE automatically apply ✅
4. No manual grants needed ever again! 🎉

## 🚀 Prerequisites

**Required:**
- Snowflake account (organization + account name)
- ACCOUNTADMIN access
- Terraform >= 1.0
- Git

**Accounts Needed:**
- [Snowflake Trial](https://signup.snowflake.com/) (30-day free with $400 credits)
- [dbt Cloud](https://www.getdbt.com/signup/) (Free developer tier)
- [Polygon.io](https://polygon.io/pricing) (Free tier: 5 API calls/min)

## 📋 Setup Instructions

### **1. Find Your Snowflake Details**

Log into Snowflake and run:
```sql
SELECT CURRENT_ORGANIZATION_NAME();  -- e.g., "WFGHGFL"
SELECT CURRENT_ACCOUNT_NAME();        -- e.g., "CN64366"
```

### **2. Configure Variables**
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
snowflake_organization_name = "WFGHGFL"       # Your org
snowflake_account_name      = "CN64366"        # Your account
snowflake_username          = "YOUR_USERNAME"  # ACCOUNTADMIN user
snowflake_password          = "YOUR_PASSWORD"  # Your password
snowflake_role              = "ACCOUNTADMIN"
```

**⚠️ CRITICAL**: Add `terraform.tfvars` to `.gitignore` (already done)

### **3. Initialize Terraform**
```bash
terraform init
```

Expected output:
```
Initializing the backend...
Initializing provider plugins...
- Finding snowflake-labs/snowflake versions matching ">= 2.9.0"...
- Installing snowflake-labs/snowflake v2.9.0...

Terraform has been successfully initialized!
```

### **4. Review Changes**
```bash
terraform plan
```

You should see **~29 resources** to be created:
- 1 database
- 4 schemas
- 1 warehouse
- 3 roles
- 2 users
- 18+ grant resources

### **5. Apply Configuration**
```bash
terraform apply
```

Type `yes` when prompted. Apply takes ~30-60 seconds.

**Success output:**
```
Apply complete! Resources: 29 added, 0 changed, 0 destroyed.
```

### **6. Verify in Snowflake**
```sql
-- Check database
SHOW DATABASES LIKE 'STOCK_ANALYTICS';

-- Check schemas
SHOW SCHEMAS IN DATABASE STOCK_ANALYTICS;

-- Check warehouse
SHOW WAREHOUSES LIKE 'ANALYTICS_WH';

-- Check roles
SHOW ROLES LIKE 'AIRBYTE_ROLE';
SHOW ROLES LIKE 'DBT_ROLE';

-- Verify permissions
SHOW GRANTS TO ROLE AIRBYTE_ROLE;
SHOW GRANTS TO ROLE DBT_ROLE;
```

## 🔌 Integration Credentials

### **For Airbyte (Snowflake Destination)**

| Field | Value |
|-------|-------|
| **Host** | `WFGHGFL-CN64366.snowflakecomputing.com` |
| **Role** | `AIRBYTE_ROLE` |
| **Warehouse** | `ANALYTICS_WH` |
| **Database** | `STOCK_ANALYTICS` |
| **Default Schema** | `RAW` |
| **Username** | `AIRBYTE_USER` |
| **Password** | `AirbyteStock2025!` (change after setup!) |

### **For dbt Cloud (Development Environment)**

| Field | Value |
|-------|-------|
| **Account** | `WFGHGFL-CN64366` |
| **Role** | `DBT_ROLE` |
| **Warehouse** | `ANALYTICS_WH` |
| **Database** | `STOCK_ANALYTICS` |
| **Schema** | `DBT_DEV` |
| **Username** | `DBT_USER` |
| **Password** | `DbtTransform2025!` (change after setup!) |

### **For dbt Cloud (Production Environment)**

Same as above, but:
- **Schema**: `MARTS`
- **Target Name**: `prod`

## 📁 File Structure
```
terraform/
├── providers.tf              # Terraform + Snowflake provider config
├── variables.tf              # All variable declarations
├── snowflake.tf              # Main infrastructure (460 lines)
│   ├── Database & Schemas
│   ├── Warehouse
│   ├── Roles & Users
│   ├── AIRBYTE_ROLE permissions
│   ├── DBT_ROLE permissions
│   ├── ACCOUNTADMIN ownership grants
│   └── Future ownership transfers
├── terraform.tfvars.example  # Template
├── terraform.tfvars          # Your secrets (gitignored!)
└── README.md                 # This file
```

## 🔐 Security Best Practices

### **1. Secrets Management**
```bash
# Never commit these files:
terraform.tfvars
*.tfstate
*.tfstate.backup
.terraform/
```

### **2. Rotate Default Passwords**
```sql
USE ROLE ACCOUNTADMIN;

-- Change service account passwords
ALTER USER AIRBYTE_USER SET PASSWORD = 'NewSecurePassword123!';
ALTER USER DBT_USER SET PASSWORD = 'AnotherSecurePassword456!';
```

### **3. Enable MFA**
Enable multi-factor authentication on your personal Snowflake account (not service accounts).

### **4. Audit Regularly**
```sql
-- Check who has what access
SHOW GRANTS TO ROLE AIRBYTE_ROLE;
SHOW GRANTS TO ROLE DBT_ROLE;

-- Check recent queries
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE USER_NAME IN ('AIRBYTE_USER', 'DBT_USER')
ORDER BY START_TIME DESC
LIMIT 100;
```

## 💰 Cost Optimization

### **Warehouse Configuration**
- **Size**: XSMALL (smallest, $2/credit-hour)
- **Auto-suspend**: 60 seconds (stops when idle)
- **Auto-resume**: Enabled (starts when queried)

### **Storage Optimization**
- **Views** in staging/intermediate (no storage)
- **Tables** only in marts (query-optimized)
- **Clustering**: Not needed at this scale

### **Estimated Monthly Costs**
```
Compute (XSMALL):  ~10 hours/month × $2/hour = $20
Storage:            ~1 GB × $40/TB = $0.04
Total:              ~$5-10/month (with free trial credits)
```

### **Monitor Costs**
```sql
-- Check warehouse usage
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE WAREHOUSE_NAME = 'ANALYTICS_WH'
ORDER BY START_TIME DESC;

-- Check storage
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.STORAGE_USAGE
ORDER BY USAGE_DATE DESC;
```

## 🐛 Troubleshooting

### **Issue: "Failed to auth for unknown reason. HTTP: 404"**

**Cause**: Incorrect organization or account name.

**Solution**:
```sql
-- Run these in Snowflake to get correct values
SELECT CURRENT_ORGANIZATION_NAME();
SELECT CURRENT_ACCOUNT_NAME();

-- Update terraform.tfvars with exact values (case-sensitive!)
```

---

### **Issue: "Insufficient privileges to operate on schema 'RAW'"**

**Cause**: Grants didn't apply or were revoked.

**Solution**:
```bash
# Re-apply grants
terraform apply -target=snowflake_grant_privileges_to_account_role.airbyte_raw_schema

# Or manually grant
USE ROLE ACCOUNTADMIN;
GRANT ALL PRIVILEGES ON SCHEMA STOCK_ANALYTICS.RAW TO ROLE AIRBYTE_ROLE;
```

---

### **Issue: dbt can't read tables created by Airbyte**

**Cause**: Future ownership grants not working.

**Solution**:
```sql
USE ROLE ACCOUNTADMIN;

-- Transfer existing table ownership
GRANT OWNERSHIP ON ALL TABLES IN SCHEMA STOCK_ANALYTICS.RAW 
TO ROLE ACCOUNTADMIN COPY CURRENT GRANTS;

-- Grant SELECT to DBT
GRANT SELECT ON ALL TABLES IN SCHEMA STOCK_ANALYTICS.RAW TO ROLE DBT_ROLE;
```

---

### **Issue: "Error: Terraform state locked"**

**Cause**: Previous `terraform apply` didn't finish cleanly.

**Solution**:
```bash
# Force unlock (use with caution!)
terraform force-unlock <LOCK_ID>
```

---

### **Issue: Want to start fresh**

**Solution**:
```bash
# Destroy everything
terraform destroy

# Then re-apply
terraform apply
```

## 🧪 Testing Your Setup

### **1. Test Airbyte Connection**
```sql
USE ROLE AIRBYTE_ROLE;
USE WAREHOUSE ANALYTICS_WH;

-- Should succeed
CREATE TABLE STOCK_ANALYTICS.RAW.TEST_TABLE (id INT);
DROP TABLE STOCK_ANALYTICS.RAW.TEST_TABLE;

-- Should fail (read-only on other schemas)
CREATE TABLE STOCK_ANALYTICS.MARTS.TEST_TABLE (id INT);
```

### **2. Test dbt Connection**
```sql
USE ROLE DBT_ROLE;
USE WAREHOUSE ANALYTICS_WH;

-- Should succeed (can read RAW)
SELECT * FROM STOCK_ANALYTICS.RAW.AAPL_STOCK_API LIMIT 5;

-- Should succeed (can write to DBT_DEV)
CREATE TABLE STOCK_ANALYTICS.DBT_DEV.TEST_TABLE AS SELECT 1;
DROP TABLE STOCK_ANALYTICS.DBT_DEV.TEST_TABLE;

-- Should fail (can't write to RAW)
CREATE TABLE STOCK_ANALYTICS.RAW.TEST_TABLE (id INT);
```

### **3. Test Future Ownership**
```sql
USE ROLE AIRBYTE_ROLE;

-- Create a test table
CREATE TABLE STOCK_ANALYTICS.RAW.OWNERSHIP_TEST (id INT);

-- Check owner (should be ACCOUNTADMIN, not AIRBYTE_ROLE!)
SHOW TABLES LIKE 'OWNERSHIP_TEST' IN SCHEMA STOCK_ANALYTICS.RAW;

-- Clean up
USE ROLE ACCOUNTADMIN;
DROP TABLE STOCK_ANALYTICS.RAW.OWNERSHIP_TEST;
```

If owner is **ACCOUNTADMIN**, your future ownership grants are working! ✅

## 🔄 Updating Infrastructure

### **Adding a New Schema**
```hcl
# In snowflake.tf, add:
resource "snowflake_schema" "new_schema" {
  database = snowflake_database.stock_analytics_db.name
  name     = "NEW_SCHEMA"
  comment  = "Description"
}
```

Then:
```bash
terraform plan   # Review changes
terraform apply  # Apply
```

### **Changing Warehouse Size**
```hcl
# In snowflake.tf, change:
resource "snowflake_warehouse" "analytics_wh" {
  warehouse_size = "SMALL"  # Was XSMALL
  # ...
}
```

### **Adding a New Role**
See existing role definitions and follow the same pattern with appropriate grants.

## 📚 Additional Resources

- [Terraform Snowflake Provider Docs](https://registry.terraform.io/providers/Snowflake-Labs/snowflake/latest/docs)
- [Snowflake RBAC Guide](https://docs.snowflake.com/en/user-guide/security-access-control-overview.html)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [Snowflake Cost Optimization](https://docs.snowflake.com/en/user-guide/cost-exploring.html)

## 🤝 Contributing

Found an issue? Have a suggestion?
1. Fork the repo
2. Create a feature branch
3. Submit a pull request

## 📝 License

This project is open source and available under the MIT License.

---

⚡ **Pro Tip**: Run `terraform plan` before every `apply` to catch issues early!
