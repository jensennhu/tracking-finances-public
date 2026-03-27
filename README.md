# Tracking Finances

An automated personal finance pipeline that pulls live bank/investment data from Google Sheets, processes it in R, and renders interactive HTML dashboards on a daily schedule via GitHub Actions. A summary is emailed each morning.

---

## What It Does

```
Google Sheets (Plaid bank feeds)
        │
        ▼
01a_data_prep_live.R        ← cleans balances, transactions, budget
        │
        ▼
  .RDS intermediates
        │
        ├──▶ 02a_data_analytics.Rmd   → Main finance dashboard (HTML)
        └──▶ 03a_md_accounts.Rmd      → Daily email snapshot (Markdown)

GitHub Actions runs the full pipeline daily at 7 AM UTC,
commits outputs, and emails the account summary.
```

---

## Reports

### Finance Visualizations Markdown (`02a_data_analytics.Rmd`)
- **Checking account threshold** — bar chart vs. a configurable buffer amount
- **Net worth over time** — multi-panel: all-time, 6-month, 3-month views broken down by account type (brokerage/IRA, savings/checking)
- **Accounts overview** — interactive table with current balance and month-over-month change
- **Income vs. spending** — paycheck overlaid with net savings, monthly net % of income
- **Budget tracker** — current and previous month: actual vs. budget per category, color-coded status
- **Spending heatmaps** — budget categories × months; daily transactions × category
- **Transaction detail** — filterable table of all transactions this month

### Daily Email Snapshot (`03a_md_accounts.Rmd`)
- Account balances with since-yesterday change indicators
- Sent as an HTML email via GitHub Actions

---

## Tech Stack

| Layer | Tools |
|-------|-------|
| Data source | [Plaid](https://plaid.com/) → Google Sheets |
| Data ingestion | `googlesheets4`, `googledrive` |
| Data processing | `dplyr`, `tidyr`, `lubridate`, `janitor` |
| Visualization | `ggplot2`, `patchwork` |
| Reporting | `rmarkdown`, `DT`, `formattable`, `fontawesome` |
| Automation | GitHub Actions (daily cron) |
| Hosting | Cloudflare Pages |

---

## Project Structure

```
├── scripts/
│   ├── config.R                    # All configurable constants (accounts, thresholds, etc.)
│   ├── functions.R                 # Shared visualization functions
│   ├── 01a_data_prep_live.R        # Data ingestion & cleaning
│   ├── 02a_data_analytics.Rmd      # Main finance dashboard
│   └── 03a_md_accounts.Rmd         # Daily email snapshot
├── .github/workflows/
│   └── run-auto.yml                # Daily automation pipeline
└── personal_finance.Rproj
```

---

## Setup

### 1. Google Sheets

Create a Google Sheet with three tabs matching these exact names:
- `Account Balances` — columns: `date`, `name`, `mask`, `account_id`, `account_subtype`, `official_name`, `value_usd`
- `Transactions (Running)` — columns: `date`, `name`, `merchant_name`, `amount`, `plaid_category_1`, `plaid_category_2`, `plaid_category_3`
- `Budget` — columns: `category`, `monthly_budget`

Data can be populated manually or via a Plaid integration.

### 2. Google Cloud Service Account

1. Create a project in [Google Cloud Console](https://console.cloud.google.com/)
2. Enable **Google Sheets API** and **Google Drive API**
3. Create a service account → add a JSON key → download it
4. Share your Google Sheet with the service account email

### 3. Configure the Project

```r
# scripts/config.R
google_email     <- "your-email@gmail.com"
google_json_path <- "resources/your-service-account-key.json"
google_sheet_id  <- "your-google-sheet-id"
```

Update the other values in `config.R` to match your accounts and preferences:
- `account_masks` — map Plaid account mask digits to friendly names
- `checking_account_buffer` — your target checking account minimum
- `archive_accounts` — accounts to hide from charts
- `investment_initial_balance`, `investment_monthly_rate` — goal projection parameters

Place your service account JSON at the path set in `google_json_path`. Add `resources/` to `.gitignore` — **never commit credentials**.

### 4. GitHub Actions Secrets

Add these secrets to your repo (Settings → Secrets → Actions):

| Secret | Value |
|--------|-------|
| `GOOGLE_VERIFY` | Password used to encrypt the service account token |
| `MAIL_USERNAME` | Gmail address for sending the daily email |
| `MAIL_PASSWORD` | Gmail app password |

Update the `to:` and `from:` fields in `.github/workflows/run-auto.yml` with your email addresses.

### 5. Install R Dependencies

```r
install.packages(c(
  "dplyr", "tidyr", "data.table", "here", "lubridate", "janitor",
  "googlesheets4", "googledrive", "ggplot2", "patchwork", "DT",
  "formattable", "fontawesome", "htmltools", "webshot", "rmarkdown",
  "httr", "jsonlite", "scales"
))
webshot::install_phantomjs()
```

### 6. Run Locally

```r
source("scripts/01a_data_prep_live.R")
rmarkdown::render("scripts/02a_data_analytics.Rmd")
```

---

## Automation

The GitHub Actions workflow (`.github/workflows/run-auto.yml`) runs daily at 7 AM UTC:

1. Pulls fresh data from Google Sheets
2. Commits updated `.RDS` intermediates
3. Renders the finance dashboard → `index.html`
4. Renders the account snapshot → `md_accounts.md`
5. Sends the snapshot as an HTML email
