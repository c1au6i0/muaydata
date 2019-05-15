---
title: Snakes, pandas, sea born creatures and how to find them
author: c1au6io_hh
date: '2019-05-06'
slug: reticulate
categories:
  - R
  - Python
tags:
  - reticulate
  - import_csv
  - microbenchmark
  - seaborn
  - vroom
lastmod: '2019-05-06T11:46:00-04:00'
keywords: []
description: ''
comment: yes
toc: yes
autoCollapseToc: yes
contentCopyright: yes
reward: no
mathjax: no
---

What's the fastest way to read a csv file in `R`? Among the `R` packages, the ultra-fast sprinter is certainly `data.table` but...few years ago, the introduction of the package [`reticulate`](https://blog.rstudio.com/2018/03/26/reticulate-r-interface-to-python/) gave us the possibility of use `python` and in particular the library `pandas` to read files in `R`. Would `pandas` (used in `R`) be faster than `data.table`? How would its performance compare with `readr` or base `R`? Let's take a look.

<!--more-->

# Benchmark evaluation

We  start by loading few `R` libraries to read the csv file and  evaluate the performance (`microbenchmark`) of our contestants...


```r
library(tidyverse)
library(reticulate)
library(data.table)
library(microbenchmark)
```

and by getting `pandas` in the `python` environment.


```python
import pandas as pd
```

I downloaded the [dataset](https://vincentarelbundock.github.io/Rdatasets/csv/boot/amis.csv) that consists of 8437	observations of 4 variables and I placed on my home folder.



We are going to read the csv file using:

* base `R` function `read.csv`
* `pandas` function `read_csv`
* `readr::read_csv`
* `data.table::fread`

We read the file  1000 times for each of the package and record the performance with `microbenchmark::microbenchmark`


```r
mb <- microbenchmark(
          "base" = {
            read.csv("~/amis.csv", sep=",")
          },
          "readr" = {
            read_csv("~/amis.csv")
          },
          "pandas" = {py_run_string("pd.read_csv('~/amis.csv')")
          },
          "data.table" = {
            fread("~/amis.csv")
          },
          times = 1000)
```

And we summarize it

```r
mb %>% 
  group_by(expr) %>% 
  rename(package = expr) %>% 
  mutate(time_ms = time * 0.000001) %>% 
  summarize(mean = mean(time_ms), median = median(time_ms), min = min(time_ms), max = max(time_ms), sd = sd(time_ms)) %>% 
  arrange(mean) %>% 
  knitr::kable(format = "html", caption = ": Milliseconds to read a csv file")
```

<table>
<caption>Table 1: : Milliseconds to read a csv file</caption>
 <thead>
  <tr>
   <th style="text-align:left;"> package </th>
   <th style="text-align:right;"> mean </th>
   <th style="text-align:right;"> median </th>
   <th style="text-align:right;"> min </th>
   <th style="text-align:right;"> max </th>
   <th style="text-align:right;"> sd </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> data.table </td>
   <td style="text-align:right;"> 1.163429 </td>
   <td style="text-align:right;"> 1.051192 </td>
   <td style="text-align:right;"> 0.893294 </td>
   <td style="text-align:right;"> 11.988350 </td>
   <td style="text-align:right;"> 0.5746664 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> pandas </td>
   <td style="text-align:right;"> 4.174706 </td>
   <td style="text-align:right;"> 3.900311 </td>
   <td style="text-align:right;"> 3.176870 </td>
   <td style="text-align:right;"> 9.903987 </td>
   <td style="text-align:right;"> 0.9339007 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> readr </td>
   <td style="text-align:right;"> 4.763939 </td>
   <td style="text-align:right;"> 4.117349 </td>
   <td style="text-align:right;"> 3.787468 </td>
   <td style="text-align:right;"> 169.842847 </td>
   <td style="text-align:right;"> 5.5154385 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> base </td>
   <td style="text-align:right;"> 8.979738 </td>
   <td style="text-align:right;"> 8.309741 </td>
   <td style="text-align:right;"> 7.746079 </td>
   <td style="text-align:right;"> 33.335507 </td>
   <td style="text-align:right;"> 2.4232146 </td>
  </tr>
</tbody>
</table>

The faster function is still `data.table::fread` with a mean reading time of about ~1 ms,  followed by `pandas` (4.17 ms) and `readr` (4.76 ms). The R base function `read.csv` is the slowest, with reading times about 4-fold  larger than `data.table::fread`.

We could graphically visualize the `microbenchmark` performance just launching `autoplot(mb)` but that would not be fun! We come so far, why not visualize the data using `python`?

# Seaborn

First we need to convert the `R` object `mb` to `python` object.

```r
py$mb <- r_to_py(mb, convert = TRUE)
```

In what is dataframe converted in `R`?


```python
type(mb)
```

```
## <class 'pandas.core.frame.DataFrame'>
```
...of course in a `pandas Dataframe`.

Now, let's import some libraries and plot the data using `seaborn`

```python
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt

sns.set(style="whitegrid", palette="muted")

mb['time_ms'] = mb['time'] * 0.000001 # from nano seconds to millisecond

ax = sns.stripplot(x="expr", y="time_ms", data = mb)

ax  = ax.set(ylabel='Time (milliseconds)', xlabel='package')

plt.show()
```

<img src="/post/2019-04-17-reticulate_files/figure-html/p_libraries-1.png" width="672" />

# Conclusion

In this sprint race to import csv in `R`, the first place is still hold by the favourite `data.table::fread` followed by `pandas read_csv` and then by `readr::read_csv`. These two last packages/functions were really close at the final line. The base `R` function `read.csv` was not able to get to the podium and had reading times about 4-fold larger than `data.table::fread`.

Ciao Ciao!

# EDIT (05-08-2019): vroom!

Few days ago, [vroom 1.0.0](https://www.tidyverse.org/articles/2019/05/vroom-1-0-0/?fbclid=IwAR0JN1wqX8U1CarXdKbKPkkg77RlNX1bew_k6bZbINb1uZloSXvNyjotxVg) was released on CRAN, and so we have another important contestant in our competition. Let's look at an update table of the reading benchmark for the `amis.csv` file.

<table>
<caption>Table 2: : UPDATED Milliseconds to read a csv file</caption>
 <thead>
  <tr>
   <th style="text-align:left;"> package </th>
   <th style="text-align:right;"> mean </th>
   <th style="text-align:right;"> median </th>
   <th style="text-align:right;"> min </th>
   <th style="text-align:right;"> max </th>
   <th style="text-align:right;"> sd </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> data.table </td>
   <td style="text-align:right;"> 1.060955 </td>
   <td style="text-align:right;"> 1.031286 </td>
   <td style="text-align:right;"> 0.877797 </td>
   <td style="text-align:right;"> 2.874855 </td>
   <td style="text-align:right;"> 0.1540645 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> pandas </td>
   <td style="text-align:right;"> 3.897818 </td>
   <td style="text-align:right;"> 3.780800 </td>
   <td style="text-align:right;"> 3.137245 </td>
   <td style="text-align:right;"> 12.067028 </td>
   <td style="text-align:right;"> 0.6595005 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> readr </td>
   <td style="text-align:right;"> 4.298844 </td>
   <td style="text-align:right;"> 4.128091 </td>
   <td style="text-align:right;"> 3.871632 </td>
   <td style="text-align:right;"> 23.730213 </td>
   <td style="text-align:right;"> 1.3351350 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> base </td>
   <td style="text-align:right;"> 8.062673 </td>
   <td style="text-align:right;"> 7.951877 </td>
   <td style="text-align:right;"> 7.501073 </td>
   <td style="text-align:right;"> 13.467489 </td>
   <td style="text-align:right;"> 0.5136744 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> vroom </td>
   <td style="text-align:right;"> 13.325987 </td>
   <td style="text-align:right;"> 12.528962 </td>
   <td style="text-align:right;"> 11.977720 </td>
   <td style="text-align:right;"> 40.054096 </td>
   <td style="text-align:right;"> 3.2400886 </td>
  </tr>
</tbody>
</table>

Under these conditions, `vroom` appears to be even slower than base `R` in terms of reading times

<img src="/post/2019-04-17-reticulate_files/figure-html/unnamed-chunk-2-1.png" width="672" />

To undestand why, we need to take a look at our `amis.csv` data.


```
## Classes 'data.table' and 'data.frame':	8437 obs. of  4 variables:
##  $ speed  : int  26 26 26 26 27 28 28 28 28 29 ...
##  $ period : int  1 1 1 1 1 1 1 1 1 1 ...
##  $ warning: int  1 1 1 1 1 1 1 1 1 1 ...
##  $ pair   : int  1 1 1 1 1 1 1 1 1 1 ...
##  - attr(*, ".internal.selfref")=<externalptr>
```

Our data consists of numeric variables and `vroom` advantage over the other packages/fucntions is that *"character data is read from the file lazily; you only pay for the data you use"*. 
So under these conditions, `data.table::fread` is still a gold medal!


