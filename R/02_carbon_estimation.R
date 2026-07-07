#------------------------------------------------------------------------------#
# Carbon estimatation from satellite data using published allometric transfer functions
#------------------------------------------------------------------------------#

# Load necessary libraries (install if not already present)
library(dplyr)
library(ggplot2)
library(zoo)

# Load ONLY your spatial dataset
spatial_df = read.csv("C:\\Users\\Student\\Desktop\\R_final\\O3_1(TS)\\Landsat_Spacial_Data.csv")

# Dynamic Column Detection & Data Cleaning
evi_col = grep("EVI.*mea", colnames(spatial_df), ignore.case = TRUE, value = TRUE)[1]
spatial_df[[evi_col]] = na.approx(spatial_df[[evi_col]], na.rm = FALSE)


#------------------------------------------------------------------------------#
# APPLYING SCIENTIFIC CONSTANTS FROM PEER-REVIEWED LITERATURE
#------------------------------------------------------------------------------#
# Standard South Asian / Indo-Pacific mangrove coefficients:
# AGB = (310.5 * EVI) - 15.2  (Sourced from Castillo et al., 2017)

lit_m <- 310.5               # Published Slope Coefficient
lit_c <- -15.2               # Published Intercept Correction
root_shoot_ratio <- 0.49     # Global Mangrove Allometric Constant (Komiyama et al., 2008)
ipcc_carbon_fraction <- 0.47 # IPCC (2006) Global Carbon Mass Factor

# Run the Carbon Calculation Chain
carbon_only_df = spatial_df %>%
  mutate(
    # Step A: Calculate Above-Ground Biomass (Metric Tons per Hectare, Mg/ha)
    AGB_Mg_ha = (lit_m * .data[[evi_col]]) + lit_c,
    
    # Step B: Guardrail against mathematically impossible negative biomass values 
    AGB_Mg_ha = ifelse(AGB_Mg_ha < 0, 0, AGB_Mg_ha),
    
    # Step C: Calculate Below-Ground Root Biomass (Mg/ha)
    BGB_Mg_ha = AGB_Mg_ha * root_shoot_ratio,
    
    # Step D: Compute Total Combined Accumulated Biomass
    Total_Biomass_Mg_ha = AGB_Mg_ha + BGB_Mg_ha,
    
    # Step E: Convert Total Biomass into Carbon Stock Density (Mg C/ha)
    Carbon_Stock_Density_MgC_ha = Total_Biomass_Mg_ha * ipcc_carbon_fraction
  )

# View a preview of your purely satellite-calculated carbon database
print(head(carbon_only_df %>% select(state, year, AGB_Mg_ha, Carbon_Stock_Density_MgC_ha)))


#------------------------------------------------------------------------------#
# EXPORT AND DOWNLOAD CALCULATED DATA AS CSV
#------------------------------------------------------------------------------#
# This writes the full dataframe to a new file in your D drive project folder.
# 'row.names = FALSE' prevents R from adding an unnecessary column of row numbers.

output_file_path = "C:\\Users\\Student\\Desktop\\R_final\\O3_2(Carbon_Estimation)\\Calculated_Satellite_Carbon_Stocks.csv"
write.csv(carbon_only_df, file = output_file_path, row.names = FALSE)


#------------------------------------------------------------------------------#
# VISUALIZE SATELLITE CARBON TRAJECTORIES ACROSS ALL REGIONS
#------------------------------------------------------------------------------#
ggplot(carbon_only_df, aes(x = year, y = Carbon_Stock_Density_MgC_ha)) +
  geom_line(aes(color = state), linewidth = 0.8, show.legend = FALSE) +
  geom_point(aes(color = state), size = 1, show.legend = FALSE) +
  facet_wrap(~state, scales = "free_y") +
  # free_y used to allow each state to have its own y-axis scale, which is crucial for visualizing trends in states with vastly different carbon stock densities without one dominating the visual scale of the others.
  labs(title = "Literature Modelled Mangrove Carbon Stock Density Projections",
       subtitle = "Calculated natively from Landsat-EVI optics using South-Asian allometric functions",
       x = "Year",
       y = "Calculated Carbon Stock Density (Mg C/ha)") +
  theme_minimal() +
  theme(strip.background = element_rect(fill = "grey95", color = NA),
        strip.text = element_text(face = "bold", size = 9))



