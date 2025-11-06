# TITLE: Copernicus
# DESCRIPTION: This file aims to extract useful weather data from  
#              "USGS Landsat 9 Level 2, Collection 2, Tier 1"
#              data available on Google Earth Engine at:
#              https://developers.google.com/earth-engine/datasets/
#              catalog/LANDSAT_LC09_C02_T1_L2

### SET UP #####################################################################

# Load packages.
library("sf")
library("terra")
library("dplyr")
library("progress")

# Define paths.
dir_here <- file.path("//wsl.localhost/Ubuntu/home",
                      "girishng/local/learning",
                      "ai_sandbox_2025/data",
                      "extraction/gee")
dir_data_root <- "../../db"
dir_data_src <- file.path(dir_data_root, "___sentinal/raw")
dir_data_dst <- file.path(dir_data_root, "___sentinal/processed")

# Set working directory.
setwd(dir_here)

# LOAD & VIEW SAMPLE RASTER ####################################################
# Load raster.
data_raster <- rast(file.path(dir_data_src, "S2A_MSIL2A_20240929T105841_N0511_R094_T30SUF_20240929T153659_pt197.tif"))
# Re-project to geographic (decimal degrees, WGS84)
data_raster <- project(data_raster, "EPSG:4326")
# View on map.
plot(data_raster)

### HELPER FUNCTIONS ###########################################################

get_year_data <- function(year, pts) {
  # Extracts and saves data from all .tif files for given year
  # and geotile centroid points.
  # Arguments:
  #   year {int} -- Year.
  #   pts {SpatVector} -- Geotile centroids.
  # Returns:
  #   raster_vals {data.frame} | NULL -- All layer values for from raster.
  
  # Get all files for this year.
  tif_files <- Sys.glob(file.path(dir_src, paste0(year, "_ERA5-*.tif")))
  
  # If no files for this year, return NULL.
  if (length(tif_files) == 0) return(NULL)
  
  # Extract data for desired geotile centroids from each file.
  data <- NULL
  for (path_raster in tif_files) {

    # Load raster image.
    data_raster <- rast(path_raster)
    
    # Extract data at each geotile centroid point.
    raster_vals <- terra::extract(x = data_raster, y = pts, ID = FALSE)
    
    # If no rows, skip.
    if (nrow(raster_vals) == 0) next
    
    # Replace label indicative of missing data with NA.
    raster_vals[raster_vals == 9999] <- NA
    raster_vals <- as.data.frame(raster_vals)
    
    if (is.null(data)) {
      # First file initializes data for this year.
      data <- raster_vals
    } else {
      data <- as.data.frame(data)
      # For each geotile, keep existing value; if NA, take from raster_vals.
      idx <- is.na(data) & !is.na(raster_vals)
      data[idx] <- raster_vals[idx]
    }
  }
  
  # If no data, return NULL.
  if (is.null(data)) return(NULL)
  
  # Return raster values.
  data
}

# EXTRACT AND SAVE DATA FOR ALL YEARS ##########################################

# Load geo-tiles.
geotiles <- read.csv(path_geotiles)[, c("lon", "lat")]

# Convert geotile centroids into a SpatVector of point geometries.
# Here, CRS EPSG:4326 informs of data being in decimal degrees
pts <- vect(geotiles, geom = c("lon","lat"), crs = "EPSG:4326") 

# Defines year range to consider.
year_start <- 1952
year_end <- 2025

# Define progress bar.
pb <- progress_bar$new(format = paste(" Processing Years [:bar] ",
                                      ":percent (:elapsed) ETA: :eta"),
                       total = ((year_end - year_start) + 1),
                       clear = FALSE, width = 60)

# Loop through all years one at time.
for (year in year_start:year_end) {
  pb$tick()
  # Get data for this year.
  raster_vals <- get_year_data(year, pts)
  # Skip writing if no rows for year.
  if (is.null(raster_vals)) {
    message("No data for year ", year, ".")
    next
  }
  # Save data.
  write.csv(x = cbind(geotiles, raster_vals), row.names = FALSE,
            file = file.path(dir_dst, paste0("years/", year, ".csv")))
}

# AGGREGATE DATA FROM ALL YEARS ################################################

# Load file paths.
year_paths <- Sys.glob(file.path(dir_dst, "years/*.csv"))

# Define progress bar.
pb <- progress_bar$new(format = paste(" Aggregating Years [:bar] ",
                                      ":percent (:elapsed) ETA: :eta"),
                       total = length(year_paths), 
                       clear = FALSE, width = 60)



# Running sum of values (NAs treated as 0 only for summing).
running_sum <- NULL  

# Running count of availability (non-NA contributions per cell).
running_notna_count <- NULL

# Loop through data one year at a time.
for (path in year_paths) {
  pb$tick()
  
  # Load data for the year.
  data_year <- read.csv(path)
  
  # Drop columns "lon" and "lat". These are same as in "geotiles".
  data_year <- data_year[, !(names(data_year) %in% c("lon", "lat"))]
  
  # Make a "non-NA" indicator (1 where value exists, 0 where NA)
  notna_count <- as.data.frame(lapply(data_year, 
                                      function(x) as.numeric(!is.na(x))))
  
  # Get NA = 0 version of values.
  data_year_0 <- data_year
  data_year_0[is.na(data_year_0)] <- 0
  
  if (is.null(running_sum)) {
    # First file initializes accumulators.
    running_sum <- data_year_0
    running_notna_count <- notna_count
  } else {
    # Accumulate sums and counts element-wise.
    running_sum <- running_sum + data_year_0
    running_notna_count <- running_notna_count + notna_count
  }
}

# Divide sum by count to compute mean.
data <- as.data.frame(running_sum / running_notna_count)

# Replace all cells with 0 non-na counts with NA.
mask0 <- as.matrix(running_notna_count == 0)
data[mask0] <- NA

# Add (lon, lat) data.
data["lon"] <- geotiles["lon"]
data["lat"] <- geotiles["lat"]

# RENAME COLUMNS ###############################################################

features <- c("temperature", "forecast_albedo", 
              "surface_net_solar_radiation",
              "surface_net_thermal_radiation",
              "total_evaporation", "total_precipitation",
              "u_component_of_wind_10m", "v_component_of_wind_10m",
              "surface_pressure")
units <- c("k", "unitness", "j_m2", "j_m2", "m", "m", "m_s", "m_s", "pa")
data_summary_metrics <- c("min", "max", "mean", "p5", "p50", "p95")

# Loop over every feature.
for (i in length(features)) {
  feature <- features[i] # Get feature name.
  unit <- units[i]       # Get feature unit.
  for (m in data_summary_metrics) {
    feature_name <- paste0(feature, "_", m) # Original name.
    new_feature_name <- paste0(feature_name, "-", unit) # New name.
    names(data)[names(data) == feature_name] <- new_feature_name
  }
}

# SAVE DATA ####################################################################
write.csv(x = data, file = file.path(dir_dst, "weather.csv"), 
          row.names = FALSE)