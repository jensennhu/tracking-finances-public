# Functions 


# Plots overall net worth and sub-account values
net_worth <- function(dates, archive,
                      balance_data = balance,
                      balance_metric_data = balance_metric_per_month) {
  net <- balance_data %>%
    filter(date %in% dates) %>% 
    group_by(date) %>% 
    summarise(total = sum(value_usd, na.rm = TRUE)) %>% 
    mutate(delta = (total - lag(total)),
           perc  = delta/lag(total)*100) 
  
  net_start <- filter(net, total == first(total))$total
  net_final <- filter(net, total == last(total))$total
  net_delta <- sum(net$delta, na.rm = TRUE)
  net_perc  <- round(net_delta/net_final * 100, 1)
  
  m1 <- net %>% 
    ggplot(aes(x = date, y = total)) + 
    geom_ribbon(aes(ymin= total[1], ymax = total), fill = "#AA4371")+
    geom_point(size = 1.5) +
    geom_line(linewidth = 1) +
    scale_x_date(date_breaks = "1 month", date_labels = "%b-%Y") +
    scale_y_continuous(labels = scales::dollar_format(prefix="$")) +
    ggtitle("Net Worth Over Time", subtitle = paste0(
      scales::dollar(net_start), 
      " --> ", scales::dollar(net_final),
      " (", net_perc, "%, +", scales::dollar(net_delta),")")) +
    theme(
      plot.title = element_text(size=22),
      axis.text.x = element_text(angle = 90),
      axis.title.x=element_blank()
    ) 
  
  
  m2 <- balance_metric_data %>%
    filter(date %in% dates) %>%
    filter(account_subtype %in% c("brokerage", "ira", "roth")) %>% 
    filter(!name %in% archive) %>% 
    ggplot(aes(x = date, y = value_usd,)) +
    geom_line(linewidth = 1.5) +
    geom_ribbon(aes(ymin= 0, ymax = value_usd), fill = "#ecf7db") +
    geom_point(size = 1.5) +
    scale_x_date(date_breaks = "1 month", date_labels = "%b-%Y") +
    scale_y_continuous(labels = scales::dollar_format(prefix="$"))+
    facet_wrap(~name, scales = "free_y", ncol = 4) + 
    theme_minimal() + 
    theme(legend.position = "none",
          plot.title = element_text(size=22),
          axis.text.x = element_text(angle = 90),
          axis.title.x=element_blank()
    )
  
  m3 <- balance_metric_data %>%
    filter(date %in% dates) %>%
    filter(account_subtype %in% c("saving", "checking")) %>% 
    filter(!name %in% archive) %>% 
    ggplot(aes(x = date, y = value_usd)) +
    geom_ribbon(aes(ymin= 0, ymax = value_usd), fill = "#8878bd") +
    geom_line(linewidth = 1) +
    geom_point(size = 1.5) +
    scale_x_date(date_breaks = "1 month", date_labels = "%b-%Y") +
    scale_y_continuous(labels = scales::dollar_format(prefix="$"))+
    facet_wrap(~name, scales = "free_y", ncol = 3) + 
    theme_minimal() + 
    theme(legend.position = "none",
          plot.title = element_text(size=22),
          axis.title.x=element_blank(),
          axis.text.x = element_text(angle = 90)
    )
  
  
  return(m1 / m2 / m3)
}


gen_budget_table <- function(data, date){
  test_color <- formatter("span",
                          style = function(x) style(display = "inline-block", 
                                                    direction = "rtl", 
                                                    `border-radius` = "4px",
                                                    `padding-right` = "1px", 
                                                    `color` = ifelse(x == "(Zero spent)", "#29999AAA",
                                                                     ifelse(x == "(Within budget)", "green",
                                                                            ifelse(x == "(Over budget)", "red",
                                                                                   ifelse(x == "(Limit reached!)", "black",
                                                                                          ifelse(x == "(Not budgeted)", "#FFA53B", "white")))))))
  
  expense_formatter <- formatter(.tag = "span", 
                                 style = function(x) style(display = "inline-block", 
                                                           direction = "rtl", 
                                                           `border-radius` = "4px", 
                                                           `padding-right` = "2px", 
                                                           `background-color` = ifelse(x < 0, csscolor("pink"), 
                                                                                       ifelse(x > 0,  csscolor("#74B72E"), 
                                                                                              csscolor("#74B72E"))),
                                                           width = paste(100*proportion(abs(x)),"px",sep="")))
  
  # format state text
  state_formatter <- formatter(
    "span", style = ~ style(color = "grey",font.weight = "bold"))
  
  data %>% 
    # keep most recent month of expenses
    filter(year_month == date) %>% 
    # only expenses relevant to budget or actually spent
    filter(!is.na(monthly_budget) | expenses != 0) %>% 
    # remove paycheck
    filter(budget_cat != "Paycheck") %>% 
    select(-inrange, -total) %>% 
    mutate(
      monthly_budget = if_else(is.na(monthly_budget), 0 , monthly_budget),
      expenses = if_else(is.na(expenses), 0, expenses),
      money_left = monthly_budget + expenses,
      prop_left = if_else(monthly_budget == 0, 0, round(money_left/monthly_budget *100, 1)),
      status = case_when(
        prop_left == 100 ~ "(Zero spent)",
        prop_left > 0 & prop_left < 100 ~ "(Within budget)",
        prop_left == 0 & monthly_budget > 0 ~ "(Limit reached!)",
        prop_left == 0 & monthly_budget == 0 ~ "(Not budgeted)",
        prop_left < 0 ~ "(Over budget)"
      )
    ) %>% 
    arrange(-prop_left, -monthly_budget) %>% 
    select(-year_month, -prop_left) %>% 
    relocate(status, .after = budget_cat) %>% 
    ungroup() %>% 
    mutate(perc_total = formattable::percent(expenses/sum(expenses))) %>% 
    arrange(status, -perc_total) %>% 
    formattable(
      list(
        `budget_cat` = state_formatter,
        `expenses`   = expense_formatter,
        `status`     = test_color
      )
    )
}