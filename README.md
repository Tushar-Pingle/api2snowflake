# API to Snowflake Data Pipeline

A complete end-to-end data engineering project that provisions cloud infrastructure and builds an automated data pipeline to ingest API data into Snowflake using Airbyte.

## 🎯 Project Overview

This project demonstrates modern data engineering practices by:
- **Infrastructure as Code (IaC)**: Provisioning Snowflake resources with Terraform
- **Data Integration**: Setting up Airbyte for API → Snowflake data ingestion
- **Cloud Data Warehousing**: Building a scalable data warehouse architecture
- **Security & Access Control**: Implementing RBAC with least-privilege principles

## 🏗️ Architecture

```
┌─────────────┐      ┌──────────────┐      ┌──────────────────┐
│   API       │─────▶│   Airbyte    │─────▶│   Snowflake      │
│   Source    │      │  Integration │      │  Data Warehouse  │
└─────────────┘      └──────────────┘      └──────────────────┘
                                                     │
                                            ┌────────▼────────┐
                                            │   US_API_DATA   │
                                            │   ├── RAW       │
                                            │   └── GOLD      │
                                            └─────────────────┘
```

## 🛠️ Tech Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Infrastructure** | Terraform | Infrastructure as Code |
| **Data Warehouse** | Snowflake | Cloud data storage & compute |
| **Data Integration** | Airbyte | API → Warehouse ETL |
| **Version Control** | Git/GitHub | Code management |

## 📁 Project Structure

```
api2snowflake/
├── terraform/              # Infrastructure provisioning
│   ├── providers.tf       # Terraform & Snowflake provider config
│   ├── variables.tf       # Variable declarations
│   ├── snowflake.tf       # Snowflake resources (DB, schemas, roles, etc.)
│   ├── terraform.tfvars.example  # Template for secrets
│   └── README.md          # Terraform-specific documentation
├── .gitignore             # Protect sensitive files
└── README.md              # This file
```

## 🚀 Quick Start

### Prerequisites
- Snowflake account ([free trial available](https://signup.snowflake.com/))
- [Terraform](https://www.terraform.io/downloads) installed
- [Airbyte](https://airbyte.com/) instance (Cloud or self-hosted)
- Git installed

### Setup Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/api2snowflake.git
   cd api2snowflake
   ```

2. **Provision Snowflake infrastructure**
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your Snowflake credentials
   terraform init
   terraform plan
   terraform apply
   ```

3. **Configure Airbyte connection**
   - Use the credentials from your `terraform.tfvars`
   - Connect to Snowflake using the `AIRBYTE_USER`
   - Target database: `US_API_DATA`
   - Target schema: `RAW`

4. **Set up your API source in Airbyte**
   - Configure your API source connector
   - Link it to the Snowflake destination
   - Run your first sync!

See [`terraform/README.md`](terraform/README.md) for detailed instructions.

## 🎓 What I Learned

### Infrastructure as Code
- Writing declarative infrastructure with Terraform
- Managing cloud resources through code
- Understanding Terraform state management
- Debugging and troubleshooting Terraform configurations

### Snowflake Architecture
- Data warehouse design (databases, schemas, tables)
- Compute and storage separation
- Virtual warehouse management
- Role-Based Access Control (RBAC)

### Security & DevOps
- Secrets management and `.gitignore` patterns
- Least-privilege access principles
- Service account configuration
- Version control best practices

### Data Engineering
- Building automated ETL pipelines
- API data ingestion patterns
- Raw → transformed data architecture
- Future grants for dynamic table creation

## 🔐 Security Notes

- ⚠️ **Never commit secrets** - `terraform.tfvars` is gitignored
- 🔒 **Rotate credentials** - Change default passwords after setup
- 👤 **Use service accounts** - Dedicated users for each service
- 🛡️ **Principle of least privilege** - Grant only necessary permissions

## 📊 Infrastructure Details

### Snowflake Resources Created:
- **Database**: `US_API_DATA`
  - **RAW Schema**: Raw ingested API data
  - **GOLD Schema**: Transformed/cleansed data
- **Warehouse**: `ETL_WH` (XSMALL, auto-suspend enabled)
- **Role**: `AIRBYTE_ROLE` (limited permissions)
- **User**: `AIRBYTE_USER` (service account)

### Estimated Costs:
- Snowflake: ~$2-5/month (XSMALL warehouse, light usage)
- Airbyte: Free (self-hosted) or based on plan
- Total: Minimal for development/portfolio projects

## 🎯 Future Enhancements

- [ ] Add dbt transformations (RAW → GOLD)
- [ ] Implement CI/CD pipeline
- [ ] Add data quality tests
- [ ] Create data visualization dashboards
- [ ] Add monitoring and alerting
- [ ] Implement incremental data loading
- [ ] Add more API sources

## 🐛 Troubleshooting

See the [Terraform README](terraform/README.md#troubleshooting) for common issues and solutions.

## 📚 Resources

- [Snowflake Documentation](https://docs.snowflake.com/)
- [Terraform Snowflake Provider](https://registry.terraform.io/providers/Snowflake-Labs/snowflake/latest/docs)
- [Airbyte Documentation](https://docs.airbyte.com/)
- [My Learning Journey](https://github.com/YOUR_USERNAME) *(link to your GitHub profile)*

## 🤝 Connect With Me

- GitHub: [@YOUR_USERNAME](https://github.com/YOUR_USERNAME)
- LinkedIn: [Your Name](https://linkedin.com/in/YOUR_PROFILE)
- Portfolio: [yourwebsite.com](https://yourwebsite.com)

## 📝 License

This project is open source and available under the MIT License.

---

⭐ **If you found this project helpful, please give it a star!**
