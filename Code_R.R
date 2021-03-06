# Title: "Predicting Credit Defaults"
# author: "Isaac Sermersheim, Kevil Khadka, Jialin Xiang, Michael Manuel"
# date: "5/7/2020"
  
## Loading libraries
library(tidyverse)
library(caret)  ## For training methods
library(randomForest) ## For bagging and random forest
library(MASS) ## For lda and qda
library(ada) ## For boosting
library(gbm) ## For building the final model
library(AUC) ## For the ROC curve


### Loading and processing the data  
# The variables `sex`, `education`, `marriage`, and `default` are factors and need to changed,rather than staying defined as doubles.  

credit <- read_csv("final_train.csv")

# changing to factor one by one so we have the factor level in order.
credit$sex <- factor(credit$sex, levels = c("1", "2"))
credit$education <- factor(credit$education, levels = c("1", "2", "3", "4"))
credit$marriage <- factor(credit$marriage, levels = c("1", "2", "3"))
credit$default <- factor(credit$default, levels = c("0", "1"))

credit <- credit %>% 
  mutate(default_num = as.numeric(as.character(default)))


credit_compete <- read_csv("final_compete.csv",
                           col_types = cols(
                             id = col_double(),
                             limit_bal = col_double(),
                             sex = col_factor(),
                             education = col_factor(),
                             marriage = col_factor(),
                             age = col_double(),
                             bill_amt1 = col_double(),
                             bill_amt2 = col_double(),
                             bill_amt3 = col_double(),
                             bill_amt4 = col_double(),
                             bill_amt5 = col_double(),
                             bill_amt6 = col_double(),
                             pay_amt1 = col_double(),
                             pay_amt2 = col_double(),
                             pay_amt3 = col_double(),
                             pay_amt4 = col_double(),
                             pay_amt5 = col_double(),
                             pay_amt6 = col_double()))


### Building the models  
# As a note we aren't using `createDataPartition()` or `crossv_fold()` here because the methods we are testing use the `train()` function in the caret package which allows us to specify that k-folds cross validation is used and will do it for us. If the model has extra tuning parameters, they can be defined using `expand.grid()` and set in `train()` using the parameter `tuneGrid`.  
# The methods we tried were logistic regression, LDA, QDA, bagging, random forest, and boosting. Each method was tested by first setting a seed to ensure our results were reproducible. The arbitrary seed chosen was `0407267`. In addition, each method utilized `k`-folds cross validation with `k = 10`. Under each method we included the highest accuracy achieved with that model, the tuning parameters that lead to the best accuracy if available, and an approximate run time for the specific chunk.  

#### Logistic regression  
set.seed(0407267)
log_train <- train(default ~ . - default_num,
data = credit,
trControl = trainControl(method = "cv", number = 10),
method = "glm",
family = "binomial")
log_train

# Accuracy : 0.7922343  
# Tuning parameters : null  
# Run time : A few seconds  
# The warning this chunk throws means that this method is giving predictions that are absolute, i.e 1 or 0. This isn't good for our problem so penalized logistic regression was attempted but resulted in the same issue.    

#### LDA  
set.seed(0407267)
lda_train <- train(default ~ . - default_num,
                   data = credit,
                   method = "lda",
                   trControl = trainControl(method = "cv", number = 10), 
                   verbose = FALSE)
lda_train

# Accuracy : 0.7922751  
# Tuning parameters : null  
# Run time : a few seconds  

#### QDA
set.seed(0407267)
qda_train <- train(default ~ . - default_num,
                   data = credit,
                   method = "qda",
                   trControl = trainControl(method = "cv", number = 10), 
                   verbose = FALSE)
qda_train

# Accuracy : 0.3746629  
# Tuning parameters : null  
# Run time : a few seconds  

#### Bagging/Random forest  
# Bagging is included with random forest since it is a special case of random forest where `m = p`. We specified `train()` to use `m = 2, 4, 6, and 17`.
# 17 is used because that's when `m = p`. 6 is used because that's the rounded result from `p/3`. 4 is used because that's the rounded result of $\sqrt(p)$. 2 is used because it is a default value for this method.  

set.seed(0407267)
rf_para <- expand.grid(mtry = c(2, 4,6,17))
rf_train <- train(default ~ . - default_num,
data = credit,
method = "rf",
trControl = trainControl(method = "cv", number = 10),
tuneGrind = rf_para,
verbose = FALSE)
rf_train

# Accuracy : 0.8021042  
# Tuning parameters : `m = 11`  
# Run time : ~ 15 minutes  
# Could not identify why the specified `mtry` values were not used.  

#### Boosting  
# For boosting we specified `train()` to try different numbers of trees (50...500), the depth of the nodes to be 3, 4, and 5, the shrinkage parameter to be 0.1, 0.01, and 0.001, and the minimum number of observations in terminal nodes to be 15.  

set.seed(0407267)
gbm_para <- expand.grid(n.trees = (1:10) * 50,
interaction.depth = c(3,4,5),
shrinkage = c(0.1, 0.01, 0.001),
n.minobsinnode = 15)
boost_train <- train(default ~ . - default_num, 
data = credit, 
method = "gbm",
trControl = trainControl(method = "cv", number = 10), 
verbose = FALSE,
tuneGrid = gbm_para)
boost_train

# Accuracy : 0.8044697  
# Tuning parameters : `n.trees = 500`, `interaction.depth = 3`, `shrinkage = 0.1`, and `n.minobsinnode = 15`  
# Run time : ~ 18 minutes  

#### Testing the model and results  
# The accuracy result given by `train()` is the amount of correct classifications divided by total classifications. So taking `1 - accuracy` gives the misclassification rate, which is the score we decided to measure our methods on.  
# 
# Logistic regression misclassification rate : `0.2077657`  
# LDA misclassification rate : `0.2077249`  
# QDA misclassification rate : `0.6253371`  
# Random forest misclassification rate : `0.1978958`  
# Boosting misclassification rate : `0.1955303`  
# 
# The best misclassification rate we were able to achieve is `0.1955` and comes from a boosted model. The worst rate came from the QDA model with a misclassification rate of `0.6253`.  

#### Deployment  
set.seed(0407267)
levels(credit$default) <- c("not_default","default") ## This is needed because using '0' and '1' are not valid names in R
credit <- credit[,-19]
final_para <- expand.grid(n.trees = 500,
interaction.depth = 3,
shrinkage = 0.1,
n.minobsinnode = 15)

final_model <- train(default ~ ., 
data = credit, 
method = "gbm",
trControl = trainControl(method = "none", classProbs = TRUE), 
verbose = FALSE)
pred_final <- predict(final_model, newdata = credit_compete, type = "prob")
id_prob <- tibble(id = credit_compete$id, default = pred_final$default) ## creates a tibble of ids and predictions so they can be saved
write_csv(id_prob, "hilarioushippos_predictions.csv")
