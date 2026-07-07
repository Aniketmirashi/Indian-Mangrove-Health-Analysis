#------------------------------------------------------------------------------#
# Corelation Analysis of Mangrove Health Indices (NDVI, EVI, MVI) with Carbon Stock Sequestration
#------------------------------------------------------------------------------#

# Install and Load Required Libraries
library(ggplot2)
library(dplyr)
library(zoo)

# Load Datasets
spatial_df = read.csv("C:\\Users\\Student\\Desktop\\R_final\\O3_1(TS)\\Landsat_Spacial_Data.csv")
carbon_df  = read.csv("C:\\Users\\Student\\Desktop\\R_final\\O3_3(Corealtation)\\Statewise_Carbon_Stock_Projection_2003_2033.csv")

#------------------------------------------------------------------------------#
# Standardize UT and State Names Before Merging
#------------------------------------------------------------------------------#

# This function will clean and standardize the 'state' column in any given data frame, ensuring that variations like "Andaman", "Andaman & Nicobar", "Puducherry", and "Pondicherry" are all mapped to consistent names. This prevents mismatches during the merge step.
standardize_states = function(df) {
  df %>%
    mutate(
      state = trimws(state),
      state = case_when(
        grepl("Andaman", state, ignore.case = TRUE) ~ "Andaman and Nicobar",
        grepl("Puducherry|Pondicherry", state, ignore.case = TRUE) ~ "Puducherry",
        TRUE ~ state # Keeps everything else exactly as it was
      )
    )
}

# Clean both data frames effortlessly in one line each
spatial_df = standardize_states(spatial_df)
carbon_df  = standardize_states(carbon_df)


#------------------------------------------------------------------------------#

# Dynamic Column Detection for Indices and Carbon Stock (Case-Insensitive)
ndvi_col   = colnames(spatial_df)[grep("NDVI.*mea", colnames(spatial_df), ignore.case = TRUE)][1]
evi_col    = colnames(spatial_df)[grep("EVI.*mea", colnames(spatial_df), ignore.case = TRUE)][1]
mvi_col    = colnames(spatial_df)[grep("MVI.*mea", colnames(spatial_df), ignore.case = TRUE)][1]
carbon_col = colnames(carbon_df)[grep("carbon|stock", colnames(carbon_df), ignore.case = TRUE)][1]


# Temporal Alignment & Merging (2003 - 2025)
spatial_cleaned = spatial_df %>% filter(year <= 2025)
carbon_cleaned  = carbon_df %>% filter(year <= 2025)
merged_all      = inner_join(spatial_cleaned, carbon_cleaned, by = c("state", "year"))

# Filling missing values in the key columns using linear interpolation to ensure smooth visualizations and accurate trend lines
all_cols = c(ndvi_col, evi_col, mvi_col, carbon_col)
# The 'group_by(state)' ensures that interpolation is done separately for each state, preventing data from one state from influencing the interpolation of another. The 'na.approx' function from the 'zoo' package performs linear interpolation, and 'na.rm = FALSE' ensures that if there are leading or trailing NAs (where interpolation isn't possible), they will remain as NAs rather than being removed.
merged_all = merged_all %>%
  group_by(state) %>%
  mutate(across(all_of(all_cols), ~na.approx(.x, na.rm = FALSE))) %>%
  ungroup()


#------------------------------------------------------------------------------#
# GRAPH 1: NDVI vs. Carbon Stock (All States & UTs)
#------------------------------------------------------------------------------#
ggplot(merged_all, aes(x = .data[[ndvi_col]], y = .data[[carbon_col]])) +
  geom_point(aes(color = state), size = 1.8, alpha = 0.6, show.legend = FALSE) +
  geom_smooth(method = "lm", color = "#238B45", fill = "#E5F5E0", se = TRUE, linewidth = 0.9) +
  facet_wrap(~state, scales = "free") +
  labs(title = "Mangrove Greenness (NDVI) vs. Carbon Stock Sequestration",
       subtitle = "State-by-state historical distribution of density-to-biomass ratios 2003–2025",
       x = "Normalized Difference Vegetation Index (NDVI Mean)",
       y = "Calculated Carbon Stock") +
  theme_minimal() +
  theme(strip.background = element_rect(fill = "#E5F5E0", color = NA),
        strip.text = element_text(face = "bold", size = 9, color = "#00441B"))


#------------------------------------------------------------------------------#
# GRAPH 2: EVI vs. Carbon Stock (All States & UTs)
#------------------------------------------------------------------------------#
ggplot(merged_all, aes(x = .data[[evi_col]], y = .data[[carbon_col]])) +
  geom_point(aes(color = state), size = 1.8, alpha = 0.6, show.legend = FALSE) +
  geom_smooth(method = "lm", color = "#006D2C", fill = "#CCECE6", se = TRUE, linewidth = 0.9) +
  facet_wrap(~state, scales = "free") +
  labs(title = "Mangrove Biomass Structural Vigor (EVI) vs. Carbon Stock Sequestration",
       subtitle = "State-by-state historical distribution of density-to-biomass ratios 2003–2025",
       x = "Enhanced Vegetation Index (EVI Mean)",
       y = "Calculated Carbon Stock") +
  theme_minimal() +
  theme(strip.background = element_rect(fill = "#CCECE6", color = NA),
        strip.text = element_text(face = "bold", size = 9, color = "#00441B"))

#------------------------------------------------------------------------------#
# GRAPH 3: MVI vs. Carbon Stock (All States & UTs)
#------------------------------------------------------------------------------#
ggplot(merged_all, aes(x = .data[[mvi_col]], y = .data[[carbon_col]])) +
  geom_point(aes(color = state), size = 1.8, alpha = 0.6, show.legend = FALSE) +
  geom_smooth(method = "lm", color = "#08519C", fill = "#DEEBF7", se = TRUE, linewidth = 0.9) +
  facet_wrap(~state, scales = "free") +
  labs(title = "Mangrove Canopy Moisture Status (MVI) vs. Carbon Stock Sequestration",
       subtitle = "State-by-state historical distribution of density-to-biomass ratios 2003–2025",
       x = "Moisture Vegetation Index (MVI Mean)",
       y = "Calculated Carbon Stock") +
  theme_minimal() +
  theme(strip.background = element_rect(fill = "#DEEBF7", color = NA),
        strip.text = element_text(face = "bold", size = 9, color = "#082567"))