# TITLE: COPERNICUS/S3/OLCI
# DESCRIPTION: This file aims to extract useful weather data from  
#              "Sentinel-3 OLCI EFR: Ocean and Land Color Instrument
#              Earth Observation Full Resolution" data available on 
#              Google Earth Engine at:
#              https://developers.google.com/earth-engine/datasets/
#              catalog/COPERNICUS_S3_OLCI

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

# Set working directory.
setwd(dir_here)

# LOAD & VIEW SAMPLE RASTER ####################################################
# Load raster.
data_raster <- rast(file.path(dir_data_root, "___COPERNICUS-S3-OLCI", 
                              "2025_roi0.tif"))
# Re-project to geographic (decimal degrees, WGS84)
data_raster <- project(data_raster, "EPSG:4326")
# View on map.
plot(data_raster)

### SAVE ALL FILES IN ONE FOLDER ###############################################

# PRESENCE DATA
filenames <- list.files( 
  file.path(dir_data_root, "trn_val_tst/raw/patches_present"))
for (name in filenames) {
  path_save <- file.path(dir_data_root, "trn_val_tst/processed",
                         paste0("1-", name))
  img_rast <- rast(file.path(dir_data_root, "trn_val_tst/raw", 
                             "patches_present", name))
  terra::writeRaster(img_rast, path_save, filetype = "GTiff", overwrite = TRUE)
}

# ABSENCE DATA
filenames <- list.files(
  file.path(dir_data_root, "trn_val_tst/raw/patches_absent"))
for (name in filenames) {
  path_save <- file.path(dir_data_root, "trn_val_tst/processed",
                         paste0("0-", name))
  img_rast <- rast(file.path(dir_data_root, "trn_val_tst/raw", 
                             "patches_absent", name))
  terra::writeRaster(img_rast, path_save, filetype = "GTiff", overwrite = TRUE)
}