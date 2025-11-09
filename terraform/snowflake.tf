########################################
# Stock Analytics Infrastructure
# Provider: SnowflakeDB/snowflake v2.9.0
# Purpose: Investment analytics platform with Polygon.io data
########################################

# -----------------------------
# 1️⃣  Database
# -----------------------------
resource "snowflake_database" "stock_analytics_db" {
  name    = "STOCK_ANALYTICS"
  comment = "Database for stock market analytics from Polygon.io"
}

# -----------------------------
# 2️⃣  Schemas
# -----------------------------
resource "snowflake_schema" "raw" {
  database = snowflake_database.stock_analytics_db.name
  name     = "RAW"
  comment  = "Raw data from Airbyte ingestion"
}

resource "snowflake_schema" "staging" {
  database = snowflake_database.stock_analytics_db.name
  name     = "STAGING"
  comment  = "Staging tables for dbt intermediate transformations"
}

resource "snowflake_schema" "marts" {
  database = snowflake_database.stock_analytics_db.name
  name     = "MARTS"
  comment  = "Final analytics tables for reporting"
}

resource "snowflake_schema" "dbt_dev" {
  database = snowflake_database.stock_analytics_db.name
  name     = "DBT_DEV"
  comment  = "Development workspace for dbt"
}

# -----------------------------
# 3️⃣  Warehouse
# -----------------------------
resource "snowflake_warehouse" "analytics_wh" {
  name                = "ANALYTICS_WH"
  warehouse_size      = "XSMALL"
  auto_suspend        = 60
  auto_resume         = true
  initially_suspended = true
  comment             = "Warehouse for analytics workloads"
}

# -----------------------------
# 4️⃣  Service Roles
# -----------------------------
resource "snowflake_account_role" "airbyte_role" {
  name    = "AIRBYTE_ROLE"
  comment = "Role for Airbyte to ingest data from Polygon.io"
}

resource "snowflake_account_role" "dbt_role" {
  name    = "DBT_ROLE"
  comment = "Role for dbt to transform data"
}

resource "snowflake_account_role" "reporting_role" {
  name    = "REPORTING_ROLE"
  comment = "Read-only role for reporting tools"
}

# -----------------------------
# 5️⃣  Service Users
# -----------------------------
resource "snowflake_user" "airbyte_user" {
  name                 = "AIRBYTE_USER"
  password             = "AirbyteStock2025!"
  default_role         = snowflake_account_role.airbyte_role.name
  default_warehouse    = snowflake_warehouse.analytics_wh.name
  default_namespace    = "${snowflake_database.stock_analytics_db.name}.${snowflake_schema.raw.name}"
  must_change_password = false
  comment              = "Service account for Airbyte"
}

resource "snowflake_user" "dbt_user" {
  name                 = "DBT_USER"
  password             = "DbtTransform2025!"
  default_role         = snowflake_account_role.dbt_role.name
  default_warehouse    = snowflake_warehouse.analytics_wh.name
  default_namespace    = "${snowflake_database.stock_analytics_db.name}.${snowflake_schema.dbt_dev.name}"
  must_change_password = false
  comment              = "Service account for dbt"
}

resource "snowflake_grant_account_role" "airbyte_user_role" {
  role_name = snowflake_account_role.airbyte_role.name
  user_name = snowflake_user.airbyte_user.name
}

resource "snowflake_grant_account_role" "dbt_user_role" {
  role_name = snowflake_account_role.dbt_role.name
  user_name = snowflake_user.dbt_user.name
}

# -----------------------------
# 6️⃣  AIRBYTE_ROLE Permissions
# -----------------------------
resource "snowflake_grant_privileges_to_account_role" "airbyte_db_usage" {
  account_role_name = snowflake_account_role.airbyte_role.name
  privileges        = ["USAGE", "MONITOR"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.stock_analytics_db.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "airbyte_db_create_schema" {
  account_role_name = snowflake_account_role.airbyte_role.name
  privileges        = ["CREATE SCHEMA"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.stock_analytics_db.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "airbyte_raw_schema" {
  account_role_name = snowflake_account_role.airbyte_role.name
  privileges        = ["USAGE", "CREATE TABLE", "CREATE STAGE", "MONITOR"]
  on_schema {
    schema_name = "\"${snowflake_database.stock_analytics_db.name}\".\"${snowflake_schema.raw.name}\""
  }
}

resource "snowflake_grant_privileges_to_account_role" "airbyte_raw_future_tables" {
  account_role_name = snowflake_account_role.airbyte_role.name
  privileges        = ["SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE"]
  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_schema          = "\"${snowflake_database.stock_analytics_db.name}\".\"${snowflake_schema.raw.name}\""
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "airbyte_warehouse" {
  account_role_name = snowflake_account_role.airbyte_role.name
  privileges        = ["USAGE", "OPERATE", "MONITOR"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.analytics_wh.name
  }
}

# -----------------------------
# 7️⃣  DBT_ROLE Permissions - NUCLEAR VERSION
# -----------------------------
resource "snowflake_grant_privileges_to_account_role" "dbt_db_usage" {
  account_role_name = snowflake_account_role.dbt_role.name
  privileges        = ["USAGE", "MONITOR", "CREATE SCHEMA"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.stock_analytics_db.name
  }
}

# RAW schema - READ ONLY
resource "snowflake_grant_privileges_to_account_role" "dbt_raw_schema" {
  account_role_name = snowflake_account_role.dbt_role.name
  privileges        = ["USAGE", "MONITOR"]
  on_schema {
    schema_name = "\"${snowflake_database.stock_analytics_db.name}\".\"${snowflake_schema.raw.name}\""
  }
}

resource "snowflake_grant_privileges_to_account_role" "dbt_raw_tables" {
  account_role_name = snowflake_account_role.dbt_role.name
  privileges        = ["SELECT"]
  on_schema_object {
    all {
      object_type_plural = "TABLES"
      in_schema          = "\"${snowflake_database.stock_analytics_db.name}\".\"${snowflake_schema.raw.name}\""
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "dbt_raw_future_tables" {
  account_role_name = snowflake_account_role.dbt_role.name
  privileges        = ["SELECT"]
  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_schema          = "\"${snowflake_database.stock_analytics_db.name}\".\"${snowflake_schema.raw.name}\""
    }
  }
}

# STAGING, MARTS, DBT_DEV - FULL GOD MODE
resource "snowflake_grant_privileges_to_account_role" "dbt_staging_schema" {
  account_role_name = snowflake_account_role.dbt_role.name
  privileges        = ["ALL PRIVILEGES"]
  on_schema {
    schema_name = "\"${snowflake_database.stock_analytics_db.name}\".\"${snowflake_schema.staging.name}\""
  }
}

resource "snowflake_grant_privileges_to_account_role" "dbt_marts_schema" {
  account_role_name = snowflake_account_role.dbt_role.name
  privileges        = ["ALL PRIVILEGES"]
  on_schema {
    schema_name = "\"${snowflake_database.stock_analytics_db.name}\".\"${snowflake_schema.marts.name}\""
  }
}

resource "snowflake_grant_privileges_to_account_role" "dbt_dev_schema" {
  account_role_name = snowflake_account_role.dbt_role.name
  privileges        = ["ALL PRIVILEGES"]
  on_schema {
    schema_name = "\"${snowflake_database.stock_analytics_db.name}\".\"${snowflake_schema.dbt_dev.name}\""
  }
}

resource "snowflake_grant_privileges_to_account_role" "dbt_warehouse" {
  account_role_name = snowflake_account_role.dbt_role.name
  privileges        = ["USAGE", "OPERATE", "MONITOR"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.analytics_wh.name
  }
}

# -----------------------------
# 8️⃣  ACCOUNTADMIN - GOD MODE EVERYTHING
# -----------------------------
resource "snowflake_grant_privileges_to_account_role" "admin_db" {
  account_role_name = "ACCOUNTADMIN"
  privileges        = ["ALL PRIVILEGES"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.stock_analytics_db.name
  }
}