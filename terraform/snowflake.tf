########################################
# Snowflake Infrastructure for API Data
# Provider: SnowflakeDB/snowflake v2.9.0
########################################

# -----------------------------
# 1️⃣  Database
# -----------------------------
resource "snowflake_database" "US_API_db" {
  name    = "US_API_DATA"
  comment = "DB to store data ingested from API using Airbyte"
}

# -----------------------------
# 2️⃣  Schemas
# -----------------------------
resource "snowflake_schema" "raw" {
  database = snowflake_database.US_API_db.name
  name     = "RAW"
  comment  = "Schema for raw ingested API data"
}

resource "snowflake_schema" "gold" {
  database = snowflake_database.US_API_db.name
  name     = "GOLD"
  comment  = "Schema for transformed data"
}

# -----------------------------
# 3️⃣  Warehouse
# -----------------------------
resource "snowflake_warehouse" "etl_wh" {
  name                = "ETL_WH"
  warehouse_size      = "XSMALL"
  auto_suspend        = 60   # suspend after 60s of inactivity
  auto_resume         = true # automatically start when a query runs
  initially_suspended = true
  comment             = "Warehouse for API ingestion and transformation jobs"
}

# -----------------------------
# 4️⃣  Airbyte Role & User
# -----------------------------

# Create Airbyte account role
resource "snowflake_account_role" "airbyte_role" {
  name    = "AIRBYTE_ROLE"
  comment = "Role for Airbyte to write API data in RAW schema"
}

# Create Airbyte user
resource "snowflake_user" "airbyte_user" {
  name                 = "AIRBYTE_USER"
  password             = "Password123456789!" # temporary; rotate later
  default_role         = snowflake_account_role.airbyte_role.name
  default_warehouse    = snowflake_warehouse.etl_wh.name
  default_namespace    = "${snowflake_database.US_API_db.name}.${snowflake_schema.raw.name}"
  must_change_password = false
  comment              = "User for Airbyte connection"
}

# Grant role to user
resource "snowflake_grant_account_role" "airbyte_user_role" {
  role_name = snowflake_account_role.airbyte_role.name
  user_name = snowflake_user.airbyte_user.name
}

# -----------------------------
# 5️⃣ Grants & Privileges
# -----------------------------

# Grant USAGE on the database
resource "snowflake_grant_privileges_to_account_role" "airbyte_db_usage" {
  account_role_name = snowflake_account_role.airbyte_role.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.US_API_db.name
  }
}

# Grant USAGE and CREATE TABLE on the RAW schema
resource "snowflake_grant_privileges_to_account_role" "airbyte_schema_usage" {
  account_role_name = snowflake_account_role.airbyte_role.name
  privileges        = ["USAGE", "CREATE TABLE"]
  on_schema {
    schema_name = "\"${snowflake_database.US_API_db.name}\".\"${snowflake_schema.raw.name}\""
  }
}

# Grant USAGE on the warehouse
resource "snowflake_grant_privileges_to_account_role" "airbyte_wh_usage" {
  account_role_name = snowflake_account_role.airbyte_role.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.etl_wh.name
  }
}

# Grant future table privileges in RAW schema
resource "snowflake_grant_privileges_to_account_role" "airbyte_future_tables" {
  account_role_name = snowflake_account_role.airbyte_role.name
  privileges        = ["SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE"]
  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_schema          = "\"${snowflake_database.US_API_db.name}\".\"${snowflake_schema.raw.name}\""
    }
  }
}

# Grant MONITOR privilege on database (needed for connection testing)
resource "snowflake_grant_privileges_to_account_role" "airbyte_db_monitor" {
  account_role_name = snowflake_account_role.airbyte_role.name
  privileges        = ["MONITOR"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.US_API_db.name
  }
}

# Grant MONITOR privilege on warehouse (needed for query execution visibility)
resource "snowflake_grant_privileges_to_account_role" "airbyte_wh_monitor" {
  account_role_name = snowflake_account_role.airbyte_role.name
  privileges        = ["MONITOR", "OPERATE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.etl_wh.name
  }
}

# Grant MONITOR and CREATE STAGE on schema (Airbyte may need internal stages)
resource "snowflake_grant_privileges_to_account_role" "airbyte_schema_extras" {
  account_role_name = snowflake_account_role.airbyte_role.name
  privileges        = ["MONITOR", "CREATE STAGE"]
  on_schema {
    schema_name = "\"${snowflake_database.US_API_db.name}\".\"${snowflake_schema.raw.name}\""
  }
}

# Grant CREATE SCHEMA on database (Airbyte needs this to create tables)
resource "snowflake_grant_privileges_to_account_role" "airbyte_db_create_schema" {
  account_role_name = snowflake_account_role.airbyte_role.name
  privileges        = ["CREATE SCHEMA"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.US_API_db.name
  }
}