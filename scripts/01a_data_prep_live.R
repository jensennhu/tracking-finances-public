# Load libraries
library(dplyr)
library(tidyr)
library(data.table)
library(here)
library(lubridate)
library(janitor)
library(googlesheets4)

# filepaths
data   <- here("01_Data")
inter  <- here("02_Intermediate")
output <- here("03_Output")

source(here("scripts", "config.R"))

## Install the development version from GitHub
# if (!require("remotes")) install.packages("remotes")
# remotes::install_github("jdtrat/tokencodr")

# authentications
# gs4_auth(email = google_email, path = google_json_path) 
# tokencodr::encrypt_token(service = "google-verify", 
#                          input = google_json_path, 
#                          destination = "~/Documents/GitHub/personal_finances/resources/")
# authenticate
googlesheets4::gs4_auth(email = google_email, path = google_json_path)

# read in
balance      <- read_sheet(google_sheet_id, sheet = "Account Balances")
transactions <- read_sheet(google_sheet_id, sheet = "Transactions (Running)")
budget       <- read_sheet(google_sheet_id, sheet = "Budget")

#-------------------------------------------------------------------------------
#
# Pre-processing
#
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Clean & Create constructs for balance data
#-------------------------------------------------------------------------------
balance <- balance %>%
  janitor::clean_names() %>%
  mutate(
    name = if_else(name == "CREDIT CARD", paste0(name, " (", official_name, ")"), name),
    name = {
      mapped <- unname(account_masks[as.character(mask)])
      ifelse(!is.na(mapped), mapped, name)
    }
  ) %>%
  mutate(
    date  = ymd(date),
    year  = year(date),
    month = month(date),
    week  = week(date),
    day   = day(date)
  ) %>%
  filter(mask != exclude_mask,
         date < date("2025/03/01")) 

# determine max dates each month w/data
dates_clean <- balance %>% 
  group_by(date)%>%
  # identify dates containing missing account values
  mutate(miss_date = max(as.numeric(is.na(value_usd))))%>%
  ungroup() %>%
  # keep dates w/complete data
  filter(miss_date == 0) %>% 
  pull(date) %>% 
  unique()

# keep dates w/complete data
balance <- balance %>% filter(date %in% dates_clean)  

# vector of latest dates each month
dates_clean_monthly <- balance %>% 
  # get latest dates in each month
  group_by(month) %>% 
  mutate(max_month = max(date)) %>%
  pull(max_month) %>% 
  unique()

# most recent account balance/value 
current_balance <- balance %>% 
  filter(date == dates_clean_monthly[1]) %>% 
  select(date, name, account_id, value_current = value_usd) %>% 
  arrange(desc(value_current))

# previous month account balance/value
previous_balance <- balance %>% 
  filter(date == dates_clean_monthly[2]) %>% 
  select(account_id, account_subtype, value_previous = value_usd) %>% 
  arrange(desc(value_previous)) 

# table - account balance comparison
balance_metric_curr <- current_balance %>% 
  left_join(
    previous_balance, 
    by = c("account_id")
    ) %>% 
  adorn_totals() %>%
  mutate(
    diff = value_current - value_previous,
    delta = if_else(account_subtype == "credit card",  
                    round((value_current - value_previous)/value_current * 100),
                    round((abs(value_current) - abs(value_previous))/abs(value_current) * 100)),
    change = paste0(round(diff, 2), " (", delta, "%)")
    ) %>% 
  select(-account_id)

# account balance subset to last date pull for each month
balance_metric_per_month <- balance %>% 
  filter(date %in% dates_clean_monthly)


#-------------------------------------------------------------------------------
# Clean & Create constructs for transactions
#-------------------------------------------------------------------------------

transactions <- transactions %>% 
  janitor::clean_names() %>% 
  # convert to date
  mutate(
    date  = ymd(date),
    year  = year(date),
    month = sprintf("%02s", month(date)),
    week  = week(date),
    day   = day(date),   
    year_month = paste0(year, "_", month),
  ) %>%  filter(date < date("2025/03/01")) 


subset <- transactions %>% 
  filter(
    # drop categories that arent relevant
    (plaid_category_1 != "Payment") &
    (plaid_category_1 != "Transfer" | grepl("BILT", name) | plaid_category_2 != "Credit") & 
    (plaid_category_1 != "Transfer" | plaid_category_2 != "Debit") &
    (plaid_category_1 != "Transfer" | plaid_category_2 != "Deposit") &
    (plaid_category_1 != "Transfer" | plaid_category_2 != "Internal Account Transfer") &
    (!merchant_name %in% c("Morgan Stanley", "Internal Revenue Service", "Coinbase")) &
    (plaid_category_1 != "Interest") &
    (plaid_category_2 != "Interest Earned") &
    ((plaid_category_3 != "Stock Brokers") | is.na(plaid_category_3))
    ) %>% 
  mutate(
    # reverse the sign
    amount = amount * -1L
    ) %>% 
  mutate(
    main_category = case_when(
      plaid_category_1 == "Shops"          & !plaid_category_2 %in% c("Supermarkets and Groceries", 
                                                                      "Warehouses and Wholesale Stores",
                                                                      "Food and Beverage Store")                   ~ "Shopping",
      plaid_category_1 == "Shops"          & plaid_category_2 == "Supermarkets and Groceries"                      ~ "Groceries",
      plaid_category_1 == "Shops"          & plaid_category_2 == "Warehouses and Wholesale Stores"                 ~ "Costco",
      plaid_category_1 == "Shops"          & plaid_category_2 == "Food and Beverage Store"                         ~ "Dining out",
      plaid_category_1 == "Food and Drink" & (plaid_category_3 != "Coffee Shop" | is.na(plaid_category_3))         ~ "Dining out",
      plaid_category_3 == "Coffee Shop"                                                                            ~ "Coffee",
                                             plaid_category_2 == "Third Party" & plaid_category_3 != "Square"      ~ plaid_category_3,
      plaid_category_1 == "Transfer"       & plaid_category_2 == "Third Party" & plaid_category_3 == "Square"      ~ "Dining out",
      plaid_category_1 == "Service"        & plaid_category_2 == "Food and Beverage"                               ~ "Take-out",
      plaid_category_1 == "Service"        & plaid_category_2 == "Cable"                                           ~ "Utilities",
      plaid_category_1 == "Shops"          & plaid_category_2 == "Glass and Optometrist"                           ~ "Health",
      plaid_category_1 == "Healthcare"     & plaid_category_2 == "Healthcare Services"                             ~ "Health",
      plaid_category_1 == "Recreation"     & plaid_category_2 == "Gyms and Fitness Centers"                        ~ "Fitness",
      plaid_category_1 == "Recreation"     & plaid_category_2 == "Sports Clubs"                                    ~ "Volleyball",
      plaid_category_1 == "Recreation"     & plaid_category_2 == "Arts and Entertainment"                          ~ "Arts and Entertainment",
      plaid_category_1 == "Travel"         & plaid_category_2 == "Public Transportation Services"                  ~ "Public Transportation Services",
      plaid_category_1 == "Travel"         & plaid_category_2 == "Taxi"                                            ~ "Taxi",
      plaid_category_1 == "Service"        & plaid_category_2 == "Veterinarians"                                   ~ "Pet",
                                             plaid_category_2 == "Payroll"                                         ~ "Paycheck",
                                             plaid_category_2 == "Interest Earned"                                 ~ plaid_category_2,
      grepl(rent_merchant_pattern, name) & abs(amount) == rent_amount                                              ~ "Rent",
      grepl("verizon", tolower(name))                                                                              ~ "Utilities",
      grepl("coned", tolower(name))                                                                                ~ "Utilities",
      .default =               plaid_category_2
    )
  ) 



interest <- transactions %>% filter(plaid_category_1 == "Interest") 

#-------------------------------------------------------------------------------
# prep budget data
#-------------------------------------------------------------------------------

budget_cat <- budget %>% 
  janitor::clean_names() %>% 
  select("budget_cat" = category, monthly_budget) 


#-------------------------------------------------------------------------------
# store data as RDS
#-------------------------------------------------------------------------------

saveRDS(balance,                   file.path(inter, "balance.RDS"))
saveRDS(balance_metric_curr,       file.path(inter, "balance_metric_curr.RDS"))
saveRDS(balance_metric_per_month,  file.path(inter, "balance_metric_per_month.RDS"))
saveRDS(budget_cat,                file.path(inter, "budget.RDS"))
saveRDS(subset,                    file.path(inter, "subset.RDS"))
saveRDS(interest,                  file.path(inter, "interest.RDS"))

