# Snowflake Infrastructure Provisioning

This directory contains Terraform configuration to provision a complete Snowflake data warehouse infrastructure for API data ingestion via Airbyte.

## 🏗️ Infrastructure Components

### Resources Created:
- **Database**: `US_API_DATA` - Main data warehouse
- **Schemas**: 
  - `RAW` - For raw API data ingestion
  - `GOLD` - For transformed/cleansed data
- **Warehouse**: `ETL_WH` - Compute resources (XSMALL, auto-suspend enabled)
- **Role**: `AIRBYTE_ROLE` - Service role with least-privilege access
- **User**: `AIRBYTE_USER` - Service account for Airbyte connections

### Privileges Granted:
- ✅ Database USAGE and MONITOR
- ✅ Schema USAGE, CREATE TABLE, CREATE STAGE, and MONITOR
- ✅ Warehouse USAGE, MONITOR, and OPERATE
- ✅ Future table privileges (SELECT, INSERT, UPDATE, DELETE, TRUNCATE)

## 🚀 Prerequisites

1. **Snowflake Account**
   - Organization name and account name
   - Admin credentials (ACCOUNTADMIN or equivalent)

2. **Terraform**
   ```bash
   # Install Terraform (if not already installed)
   # macOS
   brew install terraform
   
   # Windows (using Chocolatey)
   choco install terraform
   
   # Linux
   # Download from https://www.terraform.io/downloads
   ```

3. **Snowflake Terraform Provider**
   - Automatically downloaded during `terraform init`
   - Version: >= 2.9.0

## 📋 Setup Instructions

### 1. Configure Variables

Copy the example file and fill in your Snowflake credentials:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your actual values:
```hcl
snowflake_organization_name = "YOUR_ORG"
snowflake_account_name      = "YOUR_ACCOUNT"
snowflake_username          = "YOUR_USERNAME"
snowflake_password          = "YOUR_PASSWORD"
snowflake_role              = "ACCOUNTADMIN"
```

**⚠️ IMPORTANT**: Never commit `terraform.tfvars` to version control!

### 2. Find Your Snowflake Account Details

Run these queries in your Snowflake worksheet:
```sql
SELECT CURRENT_ORGANIZATION_NAME();  -- Your organization name
SELECT CURRENT_ACCOUNT_NAME();        -- Your account name
```

### 3. Initialize Terraform

```bash
cd terraform
terraform init
```

This downloads the Snowflake provider and initializes the backend.

### 4. Review the Plan

```bash
terraform plan
```

Review the resources that will be created. You should see:
- 1 database
- 2 schemas
- 1 warehouse
- 1 role
- 1 user
- 7 grant resources

### 5. Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted to confirm.

## 🔌 Connecting Airbyte

After running `terraform apply`, use these values in Airbyte:

| Field | Value |
|-------|-------|
| Host | `{org}-{account}.snowflakecomputing.com` |
| Role | `AIRBYTE_ROLE` |
| Warehouse | `ETL_WH` |
| Database | `US_API_DATA` |
| Default Schema | `RAW` |
| Username | `AIRBYTE_USER` |
| Password | (from your terraform.tfvars) |

## 🧹 Cleanup

To destroy all resources:

```bash
terraform destroy
```

**⚠️ WARNING**: This will permanently delete the database and all data!

## 📁 File Structure

```
terraform/
├── providers.tf              # Provider configuration
├── variables.tf              # Variable declarations
├── snowflake.tf              # Main infrastructure resources
├── terraform.tfvars.example  # Template for variables
├── .gitignore                # Protects sensitive files
└── README.md                 # This file
```

## 🔐 Security Best Practices

1. **Never commit secrets** - Use `.gitignore` for `terraform.tfvars`
2. **Rotate passwords** - Change the default Airbyte password after setup
3. **Use least privilege** - The AIRBYTE_ROLE has only necessary permissions
4. **Enable MFA** - For your admin Snowflake account
5. **Monitor usage** - Track warehouse costs and query patterns

## 📊 Cost Optimization

- Warehouse is set to XSMALL (smallest size)
- Auto-suspend after 60 seconds of inactivity
- Auto-resume when queries are executed
- Estimated cost: ~$2-5/month for light usage

## 🐛 Troubleshooting

### Issue: "failed to auth for unknown reason. HTTP: 404"
**Solution**: Check that `organization_name` and `account_name` are correct and separate (not combined as `org-account`).

### Issue: "Insufficient privileges to operate on schema"
**Solution**: Ensure all grant resources were created successfully. Run `SHOW GRANTS TO ROLE AIRBYTE_ROLE;` in Snowflake.

### Issue: Terraform state file conflicts
**Solution**: If working in a team, use remote state storage (S3, Terraform Cloud).

## 📚 Additional Resources

- [Snowflake Terraform Provider Documentation](https://registry.terraform.io/providers/Snowflake-Labs/snowflake/latest/docs)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [Snowflake RBAC Guide](https://docs.snowflake.com/en/user-guide/security-access-control-overview.html)

## 🤝 Contributing

If you find issues or have suggestions:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## 📝 License

This project is open source and available under the MIT License.