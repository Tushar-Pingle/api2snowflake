# 📈 Stock Analytics Platform

A production-grade investment analytics platform that ingests real-time stock market data, transforms it through a medallion architecture, and generates actionable trading insights using the modern data stack.

## 🎯 Project Overview

This end-to-end data engineering project demonstrates enterprise-level practices:
- **Infrastructure as Code (IaC)**: Complete Snowflake provisioning with Terraform
- **Automated ETL**: Airbyte pipelines syncing daily market data from Polygon.io
- **Data Transformation**: dbt Cloud implementing medallion architecture (Bronze → Silver → Gold)
- **Advanced Analytics**: Technical indicators, trading signals, and portfolio benchmarking
- **Enterprise RBAC**: Self-healing permission model with future ownership grants

## 🏗️ Architecture
```
┌─────────────────┐      ┌──────────────────┐      ┌────────────────────────────────┐
│  Polygon.io API │─────▶│     Airbyte      │─────▶│       Snowflake Warehouse      │
│   (9 Stocks)    │ REST │  (Self-hosted)   │ JDBC │                                │
│   OHLCV Data    │      │  Daily Syncs     │      │  ┌──────────────────────────┐  │
└─────────────────┘      └──────────────────┘      │  │   RAW (Bronze)           │  │
                                                    │  │   9 Stock Tables         │  │
                                                    │  └──────────┬───────────────┘  │
                                                    │             │                  │
                         ┌──────────────────┐      │             ▼                  │
                         │    dbt Cloud     │◀─────┤  ┌──────────────────────────┐  │
                         │                  │      │  │   STAGING (Silver)       │  │
                         │  6 Models:       │      │  │   Cleaned & Unified      │  │
                         │  • Staging (1)   │      │  └──────────┬───────────────┘  │
                         │  • Intermediate  │      │             │                  │
                         │    (2)           │      │             ▼                  │
                         │  • Marts (3)     │      │  ┌──────────────────────────┐  │
                         │                  │      │  │   INTERMEDIATE (Silver)  │  │
                         └──────────────────┘      │  │   Returns & SMAs         │  │
                                                    │  └──────────┬───────────────┘  │
                                                    │             │                  │
                         ┌──────────────────┐      │             ▼                  │
                         │    Terraform     │      │  ┌──────────────────────────┐  │
                         │                  │      │  │   MARTS (Gold)           │  │
                         │  Infrastructure  │      │  │   Analytics-Ready        │  │
                         │  Provisioning    │      │  │   Trading Signals        │  │
                         │  RBAC Management │      │  └──────────────────────────┘  │
                         └──────────────────┘      │                                │
                                                    │  Database: STOCK_ANALYTICS     │
                                                    └────────────────────────────────┘
```

## 🛠️ Tech Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Data Source** | Polygon.io API | Real-time stock market data |
| **Data Integration** | Airbyte (Self-hosted) | ETL pipeline with incremental syncs |
| **Cloud Warehouse** | Snowflake | Columnar storage with compute separation |
| **Transformation** | dbt Cloud | SQL-based transformations with lineage |
| **Infrastructure** | Terraform | Complete IaC for warehouse + RBAC |
| **Version Control** | Git/GitHub | CI/CD workflows |

## 📊 Data Pipeline

### **Data Sources (9 Securities)**
- **Tech Stocks**: AAPL, MSFT, AMZN, GOOGL, META, NVDA, TSLA
- **ETFs**: QQQ (Nasdaq 100), SPY (S&P 500)
- **Data Range**: June 2025 - November 2025 (ongoing)

### **Transformation Layers**

**🥉 Bronze Layer (RAW)**
- 9 raw tables ingested by Airbyte
- OHLCV data (Open, High, Low, Close, Volume)
- Owned by AIRBYTE_ROLE

**🥈 Silver Layer (STAGING + INTERMEDIATE)**
- `stg_stock_prices`: Unified view of all 9 stocks
- `int_stock_returns`: Daily returns, volatility metrics
- `int_moving_averages`: SMA 7/30/90 day, rolling volatility

**🥇 Gold Layer (MARTS)**
- `fct_daily_stock_performance`: Daily fact table with trading signals
- `dim_stock_summary`: Latest stats per stock (30-day metrics)
- `fct_portfolio_performance`: Portfolio-level analytics vs benchmarks

## 📈 Analytics Features

### **Technical Indicators**
- Simple Moving Averages (7, 30, 90 day)
- Daily returns calculation
- 30-day rolling volatility (standard deviation)
- Volume-weighted average price (VWAP)
- Intraday volatility metrics

### **Trading Signals**
- **BUY/SELL/HOLD Recommendations**
  - Based on SMA crossovers
  - Golden Cross (SMA 7 > SMA 30) = Bullish
  - Death Cross (SMA 7 < SMA 30) = Bearish

### **Portfolio Analytics**
- Alpha calculation (excess returns vs SPY/QQQ)
- Risk-adjusted returns (Sharpe-like ratios)
- Sentiment scoring (-100 to +100)
- Market regime classification (BULL/BEAR/SIDEWAYS)

## 🚀 Quick Start

### Prerequisites
- Snowflake account ([trial available](https://signup.snowflake.com/))
- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [Airbyte](https://docs.airbyte.com/deploying-airbyte/local-deployment) (self-hosted)
- Polygon.io API key ([free tier available](https://polygon.io/))
- dbt Cloud account ([free tier](https://www.getdbt.com/signup/))

### Setup Steps

**1. Clone the repository**
```bash
git clone https://github.com/Tushar-Pingle/api2snowflake.git
cd api2snowflake
```

**2. Provision Snowflake infrastructure**
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Snowflake credentials
terraform init
terraform plan
terraform apply
```

**3. Configure Airbyte connections**
- Create 9 Polygon.io Stock API sources (one per ticker)
- Configure Snowflake destination with AIRBYTE_USER credentials
- Set sync frequency to daily
- Target database: `STOCK_ANALYTICS`, schema: `RAW`

**4. Set up dbt Cloud**
- Connect to GitHub repository
- Configure Snowflake connection with DBT_USER credentials
- Create Development and Production environments
- Run `dbt run` to build all models

See [`terraform/README.md`](terraform/README.md) for detailed instructions.

## 🎓 Key Technical Achievements

### **1. Solved Cross-Role Ownership Issues**
Implemented future ownership grants to automatically transfer table ownership from AIRBYTE_ROLE to ACCOUNTADMIN, enabling cascading permissions without manual grants.
```hcl
# Terraform configuration
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

### **2. Medallion Architecture**
Proper separation of concerns with Bronze → Silver → Gold layers, each serving distinct purposes and audiences.

### **3. dbt Lineage & Documentation**
Complete data lineage tracking with column-level documentation, making transformations auditable and maintainable.

### **4. Self-Healing Permissions**
Zero manual intervention required - future grants ensure new tables automatically inherit correct permissions.

## 📁 Project Structure
```
api2snowflake/
├── terraform/              # Infrastructure as Code
│   ├── providers.tf       # Terraform & Snowflake provider
│   ├── variables.tf       # Variable declarations
│   ├── snowflake.tf       # Complete infrastructure (460+ lines)
│   ├── terraform.tfvars.example
│   └── README.md
├── dbt_project/           # dbt Cloud configuration
│   ├── models/
│   │   ├── staging/      # Bronze → Silver
│   │   │   ├── sources.yml
│   │   │   └── stg_stock_prices.sql
│   │   ├── intermediate/ # Silver transformations
│   │   │   ├── int_stock_returns.sql
│   │   │   └── int_moving_averages.sql
│   │   └── marts/        # Gold layer
│   │       ├── fct_daily_stock_performance.sql
│   │       ├── dim_stock_summary.sql
│   │       └── fct_portfolio_performance.sql
│   └── dbt_project.yml
├── .gitignore
└── README.md
```

## 🔐 Security & Best Practices

### **RBAC Implementation**
- ✅ Service accounts for each tool (AIRBYTE_USER, DBT_USER)
- ✅ Least-privilege access (read-only where appropriate)
- ✅ Separation of duties (ingestion vs transformation)
- ✅ Future grants preventing permission drift

### **Secrets Management**
- ⚠️ **Never commit** `terraform.tfvars` or credentials
- 🔒 Use environment variables for CI/CD
- 🔑 Rotate service account passwords regularly

### **Cost Optimization**
- XSMALL warehouse with auto-suspend (60s)
- Views in staging/intermediate (no storage cost)
- Tables only in marts (optimized for query performance)
- Estimated cost: **$5-10/month** for this workload

## 📊 Infrastructure Details

### **Snowflake Resources**
- **Database**: `STOCK_ANALYTICS`
- **Schemas**: RAW, STAGING, MARTS, DBT_DEV
- **Warehouse**: `ANALYTICS_WH` (XSMALL)
- **Roles**: AIRBYTE_ROLE, DBT_ROLE, REPORTING_ROLE
- **Users**: AIRBYTE_USER, DBT_USER

### **dbt Models**
- **6 production models**
- **~800 lines of SQL**
- **Full lineage tracking**
- **Column-level documentation**

## 🎯 Future Enhancements

- [x] ~~Medallion architecture~~ ✅ Complete
- [x] ~~Technical indicators~~ ✅ SMA, volatility, returns
- [x] ~~Trading signals~~ ✅ BUY/SELL/HOLD
- [ ] Power BI dashboards
- [ ] Additional indicators (RSI, MACD, Bollinger Bands)
- [ ] Backtesting framework
- [ ] ML-based predictions
- [ ] Real-time streaming with Kafka
- [ ] Alerting system (email/Slack on signals)

## 🐛 Troubleshooting

See the [Terraform README](terraform/README.md#troubleshooting) for common issues.

### Quick Fixes
```sql
-- Grant permissions if dbt fails
USE ROLE ACCOUNTADMIN;
GRANT SELECT ON ALL TABLES IN SCHEMA STOCK_ANALYTICS.RAW TO ROLE DBT_ROLE;

-- Check current ownership
SHOW TABLES IN SCHEMA STOCK_ANALYTICS.RAW;
```

## 📚 Resources

- [Project Documentation (dbt Docs)](https://cloud.getdbt.com/) - Live lineage graph
- [Snowflake Documentation](https://docs.snowflake.com/)
- [dbt Best Practices](https://docs.getdbt.com/guides/best-practices)
- [Terraform Snowflake Provider](https://registry.terraform.io/providers/Snowflake-Labs/snowflake/latest/docs)

## 🤝 Connect With Me

- **GitHub**: [@Tushar-Pingle](https://github.com/Tushar-Pingle)
- **LinkedIn**: [Tushar Pingle](https://linkedin.com/in/YOUR_PROFILE)
- **Email**: tush.pingle@gmail.com

## 📝 License

This project is open source and available under the MIT License.

---

⭐ **If this helped you learn modern data engineering, please star this repo!**

**Built with**: Snowflake ❄️ | dbt Cloud 🔄 | Airbyte 🔌 | Terraform 🏗️
