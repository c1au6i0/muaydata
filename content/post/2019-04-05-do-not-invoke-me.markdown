---
title: Do not invoke me
author: c1au6i0
date: '2019-04-18'
slug: do-not-invoke-me
categories:
  - R
tags:
  - purrr
  - functions
  - rlang
  - invoke
  - exec
lastmod: '2019-04-18T18:45:25-04:00'
keywords: []
description: ''
comment: yes
toc: yes
autoCollapseToc: no
contentCopyright: yes
reward: no
mathjax: no
---

You know how to apply a function to a list of elements (```apply```, ```purrr:map```) but... do you know how to apply a **list of functions** to the **same data/arguments**? In this short post we will answer that question.

<!--more-->

# Iteration over multiple dataframes: map/apply family

Let's starts loading some libraries...


```r
library(PRROC)
library(rlang)
library(tidyverse)
```

...and creating a couple of dataframes with a column ```prob``` of simulated probabilities and one column ```lab``` of  classes (0 or 1).


```r
create_values <- function(seed) {
  set.seed(seed)
  tibble(prob = runif(1000, min = 0, max = 1),
         lab = rbinom(1000, 1, 0.5))
}

dfs <- map(c(16, 15), create_values)
names(dfs) <- c("df1", "df2")
str(dfs)
```

```
## List of 2
##  $ df1:Classes 'tbl_df', 'tbl' and 'data.frame':	1000 obs. of  2 variables:
##   ..$ prob: num [1:1000] 0.683 0.244 0.45 0.229 0.864 ...
##   ..$ lab : int [1:1000] 0 1 1 0 1 1 0 1 1 0 ...
##  $ df2:Classes 'tbl_df', 'tbl' and 'data.frame':	1000 obs. of  2 variables:
##   ..$ prob: num [1:1000] 0.602 0.195 0.966 0.651 0.367 ...
##   ..$ lab : int [1:1000] 1 1 0 1 0 0 0 1 1 0 ...
```

Given some probabilities and relative class labels, the package ```PRROC``` can be used to calculate the Area Under the ROC curve. Let's calculate the AUC of ```dfs$df1````.


```r
roc_1 <- roc.curve(scores.class0 = dfs$df1$prob, weights.class0 = dfs$df1$lab, curve = TRUE)
roc_1
```

```
## 
##   ROC curve
## 
##     Area under curve:
##      0.4895718 
## 
##     Curve for scores from  0.001510504  to  0.999422 
##     ( can be plotted with plot(x) )
```

Using ```purrr:pmap``` we can easily apply the ```roc.curve``` function to multiple arguments and  calculate the ROC curve of both the dataframes in ```dfs```.


```r
args1 <- list(scores.class0 = dfs$df1$prob, weights.class0 = dfs$df1$lab)

args2 <- list(scores.class0 = dfs$df2$prob, weights.class0 = dfs$df2$lab)

pmap(list(args1, args2), .f = roc.curve, curve = TRUE)
```

To reduce the repeated code, we can create a function that given a dataframe with those named columns calculate the ROC curve. We can then apply the  newly create function to the the list of ```dfs``` using ```purrr::map```. 


```r
roc_df <- function(df, ... ) {
  roc.curve(scores.class0 = df$prob, weights.class0 = df$lab, ...)
}

map(dfs, roc_df, curve = TRUE)
```

```
## $df1
## 
##   ROC curve
## 
##     Area under curve:
##      0.4895718 
## 
##     Curve for scores from  0.001510504  to  0.999422 
##     ( can be plotted with plot(x) )
## 
## 
## $df2
## 
##   ROC curve
## 
##     Area under curve:
##      0.462952 
## 
##     Curve for scores from  1.273188e-05  to  0.9980255 
##     ( can be plotted with plot(x) )
```

But what if we want to **calculate both ROC and Precision-Recall curve of the same data**? 

We could simply copy-paste the same code twice, changing only the function called. 


```r
roc.curve(scores.class0 = dfs$df1$prob, weights.class0 = dfs$df1$lab, curve = TRUE)

pr.curve(scores.class0 = dfs$df1$prob, weights.class0 = dfs$df1$lab, curve = TRUE)
```

This would get us where we want but... with **code that mostly repeats itself, and thus is potentially hard to debug and prone to errors**. 

# Invoke? Not anymore

The family of functions ```invoke_map``` can be used to **call a list of functions to a list of parameters** ( similarly to [```do.call```](https://adv-r.hadley.nz/quasiquotation.html#do-call)).

However, the ```invoke``` family of functions is no longer under development, and Lionel Henry and Hadley Wickham have suggested instead the use of ```rlang::exec``` combined with an apply function.

In particular, ```map``` is used to apply the ```rlang::exec```, and thus evaluate a list of functions and corresponding unquoted arguments.


```r
arg <- list(scores.class0 = dfs$df1$prob, weights.class0 = dfs$df1$lab, curve = TRUE)

map(list(roc.curve, pr.curve), exec, !!!arg)
```

```
## [[1]]
## 
##   ROC curve
## 
##     Area under curve:
##      0.4895718 
## 
##     Curve for scores from  0.001510504  to  0.999422 
##     ( can be plotted with plot(x) )
## 
## 
## [[2]]
## 
##   Precision-recall curve
## 
##     Area under curve (Integral):
##      0.5145464 
## 
##     Area under curve (Davis & Goadrich):
##      0.5145411 
## 
##     Curve for scores from  0.001510504  to  0.999422 
##     ( can be plotted with plot(x) )
```

Similarly, we can use ```purrr::map2``` and ```rlang::exec```  **to calculate both ROC and Precision-Recall curve of  the both the dataframes in ```dfs```** 


```r
args1 <- list(scores.class0 = dfs$df1$prob, weights.class0 = dfs$df1$lab)
args2 <- list(scores.class0 = dfs$df2$prob, weights.class0 = dfs$df2$lab)

all <- map2(rep(list(roc.curve, pr.curve),2), 
      rep(list(args1, args2), each = 2), 
      function(fn, args) exec(fn, !!!args))

str(all)
```

```
## List of 4
##  $ :List of 3
##   ..$ type : chr "ROC"
##   ..$ auc  : num 0.49
##   ..$ curve: NULL
##   ..- attr(*, "class")= chr "PRROC"
##  $ :List of 3
##   ..$ type              : chr "PR"
##   ..$ auc.integral      : num 0.515
##   ..$ auc.davis.goadrich: num 0.515
##   ..- attr(*, "class")= chr "PRROC"
##  $ :List of 3
##   ..$ type : chr "ROC"
##   ..$ auc  : num 0.463
##   ..$ curve: NULL
##   ..- attr(*, "class")= chr "PRROC"
##  $ :List of 3
##   ..$ type              : chr "PR"
##   ..$ auc.integral      : num 0.492
##   ..$ auc.davis.goadrich: num 0.492
##   ..- attr(*, "class")= chr "PRROC"
```
# Conclusions

The family of functions ```purrr::map``` can be used with ```rlang::exec``` and unquoting functions ```!!!``` to call a list of functions with a list of different arguments. 
Take a look Hadly Wickaham's  [*Advanced R*](https://adv-r.hadley.nz/quasiquotation.html) if you want to know more about *quasiquatation*. 
