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
  "0000" = "Chase Checking",
  "4444" = "Etrade Invest",
  "6666" = "RHood Roth IRA",
  "7777" = "RHood Trad IRA",
  "9999" = "CptlOne Savings"
)

# Mask values for accounts to exclude from balance analysis
exclude_mask <- c(1111, 3333)

# BILT rent transaction identification
rent_merchant_pattern <- "BILT"
rent_amount           <- 1750

# Checking account monitoring
checking_account_name   <- "Chase Checking"
checking_account_buffer <- 6500
