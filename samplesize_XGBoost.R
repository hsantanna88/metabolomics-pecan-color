library(xgboost)
library(tidyverse)
library(haven)
library(purrr)
library(fixest)

setwd("C:/Users/Desktop")

color <- read_csv("color.csv")

# Create dummy variables for "Storage_2"
color <- color %>% 
  mutate(storage = ifelse(Storage_2 == "Storage", 1, 0))


data <- color
outcome <- "L"  

XGBoost_model <- function(data, outcome, s = 50)
{
  test_rows <- sample(1:nrow(data), size = 25, replace = FALSE)
  test_data <- data[test_rows,]
  train_data <- data[-test_rows,]
  sample_rows <- sample(1:nrow(train_data), size = s, replace = FALSE)
  train_data <- train_data[sample_rows,]
  
  # Subset the outcome column using the column name
  train_Y <- as.matrix(train_data[[outcome]])
  test_Y  <- as.matrix(test_data[[outcome]])
  
  # Select predictor columns for training and testing data
  train_X <- train_data[,c(9:ncol(train_data))]  # Include the dummy variables here
  test_X <- test_data[,c(9:ncol(test_data))]  # Include the dummy variables here
  
  # Standardize the predictor variables (after selecting them)
  train_X <- scale(train_X)
  test_X <- scale(test_X)
  
  # Convert to matrix
  train_X <- as.matrix(train_X)
  test_X <- as.matrix(test_X)
  
  # Define the XGBoost model
  xgb_model <- xgboost(
    data = train_X, 
    label = train_Y, 
    objective = "reg:squarederror",  # Regression task
    nrounds = 1000,  # Number of boosting rounds
    eta = 0.1,
    max_depth = 2,
    early_stopping_rounds = 10,  # Stop if no improvement in 10 rounds
    verbose = 1  # Print progress
  )
  
  # Make predictions
  prediction <- predict(xgb_model, test_X)
  
  mse <- mean((test_Y - prediction)^2)  # Calculate MSE
  rmse <- sqrt(mse)  # Calculate RMSE from MSE
  mse_sd <- sd((test_Y - prediction)^2)
  
  # Calculate the correlation between predicted and observed values
  correlation <- cor(prediction, test_Y)
  
  return(list(rmse = rmse, mse = mse, mse_sd = mse_sd, correlation = correlation, size = s))
}

#---------------Sample Size--------------------------------------------------------------------------------
sample_size = c(50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100, 105, 110, 115, 120, 125, 130, 135, 140, 145, 150, 155, 160, 165, 170, 175, 180)
model_total <- tibble(rmse = numeric(), correlation = numeric(), size = numeric())

for(i in sample_size) {
  for(j in 1:10) {
    model_total = bind_rows(
      model_total, 
      tibble(size = i, 
             correlation = XGBoost_model(data, outcome, s = i)[[1]]$correlation,
             rmse = XGBoost_model(data, outcome, s = i)[[1]]$rmse)
    )
  }
}
# RMSE and Correlation between prediction and observation: Accuracy
model_total <- model_total %>% 
  group_by(size) %>% 
  summarise(correlation = mean(correlation), rmse = mean(rmse))


model_total <- ungroup(model_total)

# Export the data into xlsx
library(writexl)
library(openxlsx)

write_xlsx(model_total, path = "samplesize_xgboost.xlsx")
write.xlsx(model_total, file = "samplesize_xgboost.xlsx")

