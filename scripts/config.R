# config.R
# Central configuration for all hardcoded constants.
# Source this file at the top of any script that needs these values.

# Google credentials
# NOTE: the JSON file contains secrets and must be gitignored.
# Add resources/ to .gitignore before committing.
google_email     <- "your-email@gmail.com"
google_json_path <- "resources/your-service-account-key.json"
google_sheet_id  <- "your-google-sheet-id"

# Account mask -> display name mappings.
# Update here when accounts open/close or are renamed.
# Mask values are the last 4 digits of each account number (from Plaid).
account_masks <- c(
  "255"  = "Chase Checking",
  "2138" = "BOA Checking",
  "7074" = "WF Checking",
  "6369" = "Chase SD Invest",
  "1082" = "Etrade Invest",
  "5879" = "RHood Invest",
  "138"  = "RHood Roth IRA",
  "1555" = "RHood Trad IRA",
  "2443" = "RHood Income",
  "4256" = "RHood Main",
  "4048" = "CptlOne Savings"
)

# Mask values for accounts to exclude from balance analysis
exclude_mask <- c(4256, 2443)

# BILT rent transaction identification
rent_merchant_pattern <- "BILT"
rent_amount           <- 1750

# Checking account monitoring
checking_account_name   <- "Chase Checking"
checking_account_buffer <- 6500

# Accounts no longer active (excluded from net worth charts)
archive_accounts <- c("Chase SD Invest", "Roth IRA")

# Robinhood account tracking
rh_accounts   <- c("RHood Invest", "RHood Roth IRA", "RHood Trad IRA")
rh_start_date <- "2025-07-30"  # Use ymd(rh_start_date) where a Date is needed

# Investment goal projection parameters
# NOTE: monthly_rate of 0.25 = 25% monthly return; verify this is intentional
#       (25% annual ≈ 1.9% monthly)
investment_initial_balance   <- 0      # Set to your starting portfolio value
investment_monthly_rate      <- 0.25
investment_projection_months <- 15
