#------------------------------------------------------------------------------#
# SPATIAL VS. INVENTORY CARBON COMPARISON 
#------------------------------------------------------------------------------#

# Load Required Libraries
library(ggplot2)
library(dplyr)
library(tidyr)
library(zoo)


# Load Both CSV Files
spatial_carbon_path = "C:\\Users\\Student\\Desktop\\R_final\\O3_2(Carbon_Estimation)\\Calculated_Satellite_Carbon_Stock.csv"
inventory_path      = "C:\\Users\\Student\\Desktop\\R_final\\O3_4(Spacial_vs_Inventory\\Statewise_Carbon_Stock_Projection_2003_2033.csv"

spatial_df   = read.csv(spatial_carbon_path)
inventory_df = read.csv(inventory_path)


#------------------------------------------------------------------------------#
# STANDARDIZE STATE & UT NAMES (Prevents matching dropouts)
#------------------------------------------------------------------------------#
for (df_name in c("spatial_df", "inventory_df")) {
  df <- get(df_name)
  df$state = trimws(df$state)
  df$state[grep("Andaman", df$state, ignore.case = TRUE)] = "Andaman and Nicobar"
  df$state[grep("Puducherry|Pondicherry", df$state, ignore.case = TRUE)] = "Puducherry"
  assign(df_name, df)
}

# Dynamic Detection of the Inventory Column
inventory_carbon_col = grep("carbon|stock", colnames(inventory_df), ignore.case = TRUE, value = TRUE)[1]

# ------------------------------------------------------------------------------
# TEMPORAL ALIGNMENT & DATA MERGING (2003 - 2025)
# ------------------------------------------------------------------------------
comparison_master = inner_join(
  # Filter and select from spatial data
  spatial_df %>% 
    filter(year <= 2025) %>% 
    select(state, year, Carbon_Stock_Density_MgC_ha),
  
  # Filter, select, and rename inventory data simultaneously
  inventory_df %>% 
    filter(year <= 2025) %>% 
    select(state, year, Inventory_Carbon_Value = all_of(inventory_carbon_col)),
  
  by = c("state", "year")
)

# Fill missing gaps using linear interpolation to ensure smooth visualizations and accurate trend lines
comparison_master$Carbon_Stock_Density_MgC_ha = na.approx(comparison_master$Carbon_Stock_Density_MgC_ha, na.rm = FALSE)
comparison_master$Inventory_Carbon_Value       = na.approx(comparison_master$Inventory_Carbon_Value, na.rm = FALSE)

#------------------------------------------------------------------------------#
# DYNAMIC CALCULATING OF STATE-WISE VISUAL SCALING FACTORS
#------------------------------------------------------------------------------#
comparison_scaled = comparison_master %>%
  group_by(state) %>%
  mutate(
    Scale_Factor = mean(Inventory_Carbon_Value, na.rm = TRUE) / mean(Carbon_Stock_Density_MgC_ha, na.rm = TRUE),
    Spatial_Carbon_Scaled = Carbon_Stock_Density_MgC_ha * Scale_Factor
  ) %>%
  ungroup()

# ------------------------------------------------------------------------------
# GRAPH 1: DUAL TIMELINE OVERLAY (With Fixed Legend Assignment)
# ------------------------------------------------------------------------------
long_timelines = comparison_scaled %>%
  select(state, year, Spatial_Carbon_Scaled, Inventory_Carbon_Value) %>%
  pivot_longer(cols = c(Spatial_Carbon_Scaled, Inventory_Carbon_Value),
               names_to = "Carbon_Source", values_to = "Value")

ggplot(long_timelines, aes(x = year, y = Value, color = Carbon_Source)) +
  geom_line(linewidth = 1) +
  geom_point(size = 1.5) +
  facet_wrap(~state, scales = "free_y") + 
  # Explicitly ordering breaks prevents alphabetical sorting from swapping labels
  scale_color_manual(values = c("Spatial_Carbon_Scaled" = "forestgreen", "Inventory_Carbon_Value" = "black"),
                     breaks = c("Spatial_Carbon_Scaled", "Inventory_Carbon_Value"),
                     labels = c("Spatial Carbon (Satellite-Derived)", "Inventory Carbon (Projections Pool)")) +
  labs(title = "Historical Baseline Tracking: Spatial Carbon vs. Inventory Estimates",
       x = "Year",
       y = "Carbon Metrics (Relative Scale Matching)",
       color = "Dataset Source") +
  theme_minimal() +
  theme(legend.position = "bottom",
        strip.background = element_rect(fill = "grey95", color = NA),
        strip.text = element_text(face = "bold", size = 9))

# ------------------------------------------------------------------------------
# GRAPH 2: CROSS-VALIDATION SCATTER MATRIX
# ------------------------------------------------------------------------------
ggplot(comparison_scaled, aes(x = Carbon_Stock_Density_MgC_ha, y = Inventory_Carbon_Value)) +
  geom_point(aes(color = state), size = 2, alpha = 0.7, show.legend = FALSE) +
  geom_smooth(method = "lm", color = "darkred", fill = "pink", se = TRUE, linewidth = 0.9) +
  facet_wrap(~state, scales = "free") +
  labs(title = "Statistical Correlation: Spatial Carbon Density vs. Inventory Pools",
       x = "Satellite-Calculated Carbon Density (Mg C/ha)",
       y = "Reported Inventory Carbon Pool") +
  theme_minimal() +
  theme(strip.background = element_rect(fill = "grey95", color = NA),
        strip.text = element_text(face = "bold", size = 9))


# Export the clean comparison data to CSV
write.csv(comparison_scaled, "C:\\Users\\Student\\Desktop\\R_final\\O3_4(Spacial_vs_Inventory\\Spatial_vs_Inventory_Calculations.csv", row.names = FALSE)

