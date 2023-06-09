# Use the below line (uncommented) with your current working directory path as the argument
# setwd("")
# Use the below lines to install packages and depndencies if you should need them
# install.packages("tidyverse")
# install.packages("imputeTS")
# install.packages("rpart.plot")
# install.packages("caret")
library(tidyverse)
library(imputeTS)
library(rpart.plot)
library(caret)

# Read in the initial data set from source [15] in the report as a data frame.
# There are far more attributes in here than we will need to actually model anything germane to the paper, and
# there is also some cleaning that will need to be done seeing as there are more rows in here than there are actual
# universities for consideration. For our modeling purposes, we are concerned with the name of the institution, its
# location by state, and the admissions, degree paths, and tuition/fees involved. The tuition is the best way to
# approximate the kind of budget a school may possess.
dfUni <- read.csv("UniversityData.csv", header = TRUE, sep = ",", dec = ".", na.strings = c("","NA","NULL",NULL))
dfUni <- subset(dfUni, select = c(INSTNM, STABBR, ADM_RATE, SCH_DEG, TUITIONFEE_OUT, INEXPFTE))
colnames(dfUni) <- c('Institution', 'State', 'Admission_Rate', 'Degrees', 'Total_Tuition', 'Additional_Fees')
dfUni <- unique(dfUni)

# Before going any further, the data needs to have its qualitative variables ordinally encoded in order to make
# them useful for a model. Below is a function for doing just that. It takes in x (a column in a data frame,
# which represents an attribute in a set,) and makes it a numeric value according to the set of all possible values
# recorded for the qualitative responses (i.e. 1-50 for the 50 states.) Note that this does not affect NULL values.
# Expected input: x column, which may or may not be a factor
# Expected output: x column of numeric factors
ordEncode <- function(x, order = unique(x)) {
  x <- as.numeric(factor(x, levels = order, exclude = NULL))
  x
}

# With this new function, we can encode the attributes in dfUni that are not numeric, and that need to be modeled. The
# name of the institution is obviously only for identification, and is not a parameter for prediction. Additionally, the
# n_means() function from the imputeTS library replaces NA values for instances with the mean value of that column, which
# will fill in every NA value after ordinal encoding.
dfUni$State <- ordEncode(dfUni$State)
dfUni$Degrees <- ordEncode(dfUni$Degrees)
dfUni <- na_mean(dfUni)

# Now we can add our approximate vectors of adoption (which is unfortunately not specific in any public capacity,)
# which was gathered form query results supplied in [14] in the report. These vectors will be presented as columns,
# from which tables specific to each cloud computing system can be generated by copying our parent data frame.
set.seed(1)
githubc <- rep(c(0, 1), times = c(6121, 555))
githubc <- sample(githubc)
googlec <- rep(c(0, 1), times = c(5634, 1042))
googlec <- sample(googlec)
outlookc <- rep(c(0, 1), times = c(5082, 1594))
outlookc <- sample(outlookc)

# From here, we can generate our tables for modeling. Inconveniently, it will be necessary to model each table
# separately, because the training data will be different each time. Despite this, the algorithm will always be
# the same.
dfGithub <- dfUni
dfGithub$Adoption <- githubc
dfGoogle <- dfUni
dfGoogle$Adoption <- googlec
dfOutlook <- dfUni
dfOutlook$Adoption <- outlookc

# Now, we need to split each one of our data frames for technology into training and testing sets using samples. The
# seed will need to be reset for this obviously, or else sampling won't make much sense. Note that each set is split
# up with 75% training and 25% testing.
set.seed(935)
dfGithub_train<- dfGithub[sample(nrow(dfGithub), size = 5007), ]
dfGithub_test <- dfGithub[sample(nrow(dfGithub), size = 1669), ]
dfGoogle_train<- dfGoogle[sample(nrow(dfGoogle), size = 5007), ]
dfGoogle_test <- dfGoogle[sample(nrow(dfGoogle), size = 1669), ]
dfOutlook_train<- dfOutlook[sample(nrow(dfOutlook), size = 5007), ]
dfOutlook_test <- dfOutlook[sample(nrow(dfOutlook), size = 1669), ]

# From here, we can reset our seed (for sampling functions) and start generating data models that provide results.
# The trctrl variable represents the algorithm and the number of repetitions for our decision tree, which is
# generate with the train() function.
set.seed(3333)
trctrl <- trainControl(method = "repeatedcv", number = 10, repeats = 3)
#Generate a tree for the Github data
dfGithub_tree <- train(as.factor(Adoption) ~ State+Admission_Rate+Degrees+Total_Tuition+Additional_Fees, 
                       data = dfGithub_train, 
                       method = "rpart", 
                       parms = list(split = "information"), 
                       trControl=trctrl, 
                       tuneLength = 10)
#Generate a tree for the Google Drive data
dfGoogle_tree <- train(as.factor(Adoption) ~ State+Admission_Rate+Degrees+Total_Tuition+Additional_Fees, 
                       data = dfGoogle_train, 
                       method = "rpart", 
                       parms = list(split = "information"), 
                       trControl=trctrl, 
                       tuneLength = 10)
#Generate a tree for the Outlook data
dfOutlook_tree <- train(as.factor(Adoption) ~ State+Admission_Rate+Degrees+Total_Tuition+Additional_Fees, 
                       data = dfOutlook_train, 
                       method = "rpart", 
                       parms = list(split = "information"), 
                       trControl=trctrl, 
                       tuneLength = 10)

# Now, we can use predict() as part of the caret library and ConfusionMatrix() from the same library
# to actually check the accuracy of these models against the raw data. This represents the predictive power
# of the models we just generated, which in turn represents whether adoption may be trending upward or
# downward in the future based on our current metrics.
Github_predict <- predict(dfGithub_tree, newdata = dfGithub_test)
confusionMatrix(Github_predict, as.factor(dfGithub_test$Adoption))
Google_predict <- predict(dfGoogle_tree, newdata = dfGoogle_test)
confusionMatrix(Google_predict, as.factor(dfGoogle_test$Adoption))
Outlook_predict <- predict(dfOutlook_tree, newdata = dfOutlook_test)
confusionMatrix(Outlook_predict, as.factor(dfOutlook_test$Adoption))
