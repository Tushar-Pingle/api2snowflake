terraform {
  required_providers {
    snowflake = {
      source  = "SnowflakeDB/snowflake"
      version = ">= 2.9.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "snowflake" {
  # Snowflake provider v2.9.0+ uses these argument names
  organization_name = var.snowflake_organization_name
  account_name      = var.snowflake_account_name
  user              = var.snowflake_username
  password          = var.snowflake_password
  role              = var.snowflake_role
}