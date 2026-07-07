#------------------------------------------------------------------------------#
# TIME SERIES ANALYSIS & STATISTICAL METRICS FOR MODIS (NDVI, EVI, & MVI)
#------------------------------------------------------------------------------#

# Install and Load Required Libraries
# required packages= ggplot2, forecast, tseries, lubridate, dplyr, zoo
instaL.packages(c("ggplot2", "forecast", "tseries", "lubridate", "dplyr", "zoo", "forecast"))

# Load libraries
library(ggplot2)    
library(forecast)   
library(tseries)    
library(lubridate)  
library(dplyr)      
library(zoo)        
library(forecast)

# Load the Dataset
file_path = "C:\\Users\\Student\\Desktop\\R_final\\O3_1(TS)\\Landsat_Spacial_Data.csv"
data = read.csv(file_path)

#------------------------------------------------------------------------------#
# NAME STANDARDIZATION
#------------------------------------------------------------------------------#
data$state = toupper(trimws(data$state)) # Convert to uppercase and trim whitespace for uniformity

data = data %>%
  mutate(state = case_when(
    grepl("ANDHRA", state)   ~ "ANDHRA PRADESH",
    grepl("GOA", state)      ~ "GOA",
    grepl("GUJARAT", state)  ~ "GUJARAT",
    grepl("KARNATAKA", state)~ "KARNATAKA",
    grepl("KERALA", state)   ~ "KERALA",
    grepl("MAHARASH", state) ~ "MAHARASHTRA",
    grepl("ODISHA", state)   ~ "ODISHA",
    grepl("TAMIL", state)    ~ "TAMIL NADU",
    grepl("WEST", state)     ~ "WEST BENGAL",
    grepl("ANDAMAN", state)  ~ "ANDAMAN & NICOBAR",
    grepl("DADRA", state)    ~ "DADRA & NAGAR HAVELI & DAMAN & DIU",
    grepl("PUDU", state)     ~ "PUDUCHERRY",
    TRUE                     ~ state 
  )) 
# This mapping ensures that any variation in the state names (like "Andhra", "Andhra Pradesh", "ANDHRA PRADESH") will be standardized to a single format, preventing mismatches during filtering and analysis.


target_states = c(
  'ANDHRA PRADESH', 'GOA', 'GUJARAT', 'KARNATAKA', 'KERALA', 
  'MAHARASHTRA', 'ODISHA', 'TAMIL NADU', 'WEST BENGAL', 
  'ANDAMAN & NICOBAR', 'DADRA & NAGAR HAVELI & DAMAN & DIU', 'PUDUCHERRY'
)


# Define the three indices and map them to your expected CSV column names
index_map = c(
  "NDVI" = "NDVI_mean",
  "EVI"  = "EVI_mean",
  "MVI"  = "MVI_mean"
)


# Initialize master lists to accumulate data across the multi-index loop
master_hist_list  = list()
master_fc_list    = list()
master_stats_list = list()
# The above lists will store the historical data, forecasts, and statistical metrics for each index-state combination. They will be combined into global data frames after the loop completes.


#------------------------------------------------------------------------------#
# NESTED SYSTEM LOOP: DATA PROCESSING & STATS EXTRACTION
#------------------------------------------------------------------------------#
# Get a list of columns that actually exist in your dataset
valid_columns = intersect(unlist(index_map), colnames(data))

processed_data = data %>%
  # Filter the target states and sort by year
  filter(state %in% target_states) %>%
  arrange(state, year) %>%
  
  # Grouped by state 
  group_by(state) %>%
  filter(n() >= 5) %>%
  
  # Cleaning all valid index columns at once
  mutate(across(all_of(valid_columns), ~ {
    x = na.approx(.x, na.rm = FALSE)     # Fill gaps
    x = na.locf(x, na.rm = FALSE)        # Carry forward
    na.locf(x, na.rm = FALSE, fromLast = TRUE) # Carry backward
  })) %>%
  ungroup()
    

  # Calculate 3-Year Moving Average
  state_data = state_data %>%
  mutate(
    Target_Trend = rollmean(Target_Value, k = 3, fill = NA, align = "center"),
    Index        = index_label) 
    
  master_hist_list[[paste(index_label, chosen_state, sep="_")]] = state_data
    
  
    # Convert to Time Series object
    start_year = min(state_data$year)
    index_ts   = ts(state_data$Target_Value, start = start_year, frequency = 1)
    
    # Run ADF test; automatically return NAs if an error occurs
    adf_result = tryCatch(
      adf.test(index_ts, alternative = "stationary"), 
      error = function(e) list(statistic = NA, p.value = NA)
    )
    
    # Extract your metrics smoothly
    adf_stat = adf_result$statistic
    adf_p    = adf_result$p.value
    
    # MODEL FITTING (Auto-ARIMA)
    fit_model = auto.arima(index_ts, seasonal = FALSE)
    
    # Extract model order and first row of error metrics cleanly
    ord = arimaorder(fit_model)
    err = accuracy(fit_model)[1, ]
    
    # Build the statistics data frame
    state_stats = data.frame(
      Index         = index_label,
      State         = chosen_state,
      ADF_Statistic = round(adf_stat, 4),
      ADF_p_value   = round(adf_p, 4),
      Is_Stationary = ifelse(!is.na(adf_p) & adf_p < 0.05, "Yes (p<0.05)", "No (Needs Diff)"),
      Best_Model    = sprintf("ARIMA(%d,%d,%d)", ord[1], ord[2], ord[3]),
      AIC           = round(fit_model$aic, 2),
      BIC           = round(fit_model$bic, 2),
      RMSE          = round(err["RMSE"], 5),
      MAE           = round(err["MAE"], 5),
      MAPE_Pct      = round(err["MAPE"], 2)
    )
    
    # Save to the master list
    key = paste(index_label, chosen_state, sep = "_")
    master_stats_list[[key]] = state_stats
    
    # Generate the 5-year forecast
    fc = forecast(fit_model, h = 5)
    
    # Extract the last historical point to anchor the forecast
    last_yr  = tail(as.numeric(time(index_ts)), 1)
    last_val = tail(as.numeric(index_ts), 1)
    
    # Build the clean forecast data frame
    fc_df = data.frame(
      Index    = index_label,
      state    = chosen_state,
      year     = c(last_yr,  as.numeric(time(fc$mean))),
      Value    = c(last_val, as.numeric(fc$mean)),
      lower80  = c(last_val, fc$lower[, 1]),
      upper80  = c(last_val, fc$upper[, 1]),
      lower95  = c(last_val, fc$lower[, 2]),
      upper95  = c(last_val, fc$upper[, 2])
    )
    
    # Saving to the master list
    key = paste(index_label, chosen_state, sep = "_")
    master_fc_list[[key]] = fc_df

    
    clean_data = lapply(
      list(hist = master_hist_list, fc = master_fc_list, stats = master_stats_list), 
      bind_rows
    )

    
#------------------------------------------------------------------------------#
# VIEW & EXPORT STATISTICAL REPORT
#------------------------------------------------------------------------------#

# Combine all the individual state-index statistics into a single comprehensive data frame
print(statistical_sheet, row.names = FALSE)

# Define directory and filename (Forward slashes work perfectly in R on Windows!)
target_dir = "C:\\Users\\Student\\Desktop\\R_final\\O3_1(TS)"
file_name  = "Comprehensive_Landsat_Statistical_Summary.csv"

#------------------------------------------------------------------------------#
# INDIVIDUAL DASHBOARD GENERATION (MATCHING THE UPLOADED FORMAT)
#------------------------------------------------------------------------------#

# Loop through each processed index to print its distinct wrapped dashboards
for (current_index in unique(all_historical$Index)) {
  
  # Filter global frames down to the active index
  hist_sub = all_historical %>% filter(Index == current_index)
  fc_sub   = all_forecasts %>% filter(Index == current_index)
  
  # 1. Historical Trends Dashboard (Moving Average)
  p_trends = ggplot(hist_sub) +
    geom_line(aes(x = year, y = Target_Value, color = "Raw Annual Data"), linewidth = 0.5, linetype = "dashed") +
    geom_point(aes(x = year, y = Target_Value, color = "Raw Annual Data"), size = 1) +
    geom_line(aes(x = year, y = Target_Trend, color = "Long-Term Trend (3-Yr MA)"), linewidth = 1) +
    scale_color_manual(values = c("Raw Annual Data" = "lightgreen", "Long-Term Trend (3-Yr MA)" = "darkgreen")) +
    facet_wrap(~state, scales = "free_y") + 
    labs(title = paste("Consolidated Multi-State Landsat", current_index, "Trends"),
         subtitle = "Smoothing out annual random variations using a 3-Year moving average track",
         x = "Year", y = paste(current_index, "Value"), color = "Layer") +
    theme_minimal() +
    theme(legend.position = "bottom", strip.text = element_text(face="bold"))
  
  print(p_trends)
  
  # 2. Future Forecast Dashboard (Identical layout to your uploaded image)
  p_forecasts = ggplot() +
    geom_ribbon(data = fc_sub, aes(x = year, ymin = lower95, ymax = upper95), fill = "#D6E4FF", alpha = 0.6) +
    geom_ribbon(data = fc_sub, aes(x = year, ymin = lower80, ymax = upper80), fill = "#ADC6FF", alpha = 0.8) +
    geom_line(data = hist_sub, aes(x = year, y = Target_Value), color = "black", linewidth = 0.7) +
    geom_line(data = fc_sub, aes(x = year, y = Value), color = "blue", linewidth = 0.9) +
    facet_wrap(~state, scales = "free_y") + 
    labs(title = paste("Consolidated Multi-State Landsat", current_index, "5-Year Forecasts"),
         subtitle = "Shaded regions represent 80% and 95% confidence bands per state",
         x = "Year", y = paste(current_index, "Prediction")) +
    theme_minimal() +
    theme(panel.grid.minor = element_blank(), strip.text = element_text(face="bold"))
  
  print(p_forecasts)
}
