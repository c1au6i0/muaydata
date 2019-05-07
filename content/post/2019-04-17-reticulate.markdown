---
title: Snakes, pandas, sea born creatures and how to find them.
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

What's the fasted way to read a csv file in `R`? Among the `R` packages, the ultra-fast sprinter is certainly `data.table` but...few years ago, the introduction of the package [`reticulate`](https://blog.rstudio.com/2018/03/26/reticulate-r-interface-to-python/) gave us the possibility of use `python` and in particular the library `pandas` to read files in `R`. Would `pandas` (used in `R`) be faster than `data.table`? How would its performance compare with `readr` or base `R`? Let's take a look.

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

* base *R* function `read.csv`
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
<caption>Table 1 : Milliseconds to read a csv file</caption>
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
   <td style="text-align:right;"> 1.223535 </td>
   <td style="text-align:right;"> 1.097575 </td>
   <td style="text-align:right;"> 0.917987 </td>
   <td style="text-align:right;"> 19.32791 </td>
   <td style="text-align:right;"> 0.9523787 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> pandas </td>
   <td style="text-align:right;"> 4.351742 </td>
   <td style="text-align:right;"> 4.108359 </td>
   <td style="text-align:right;"> 3.311811 </td>
   <td style="text-align:right;"> 19.04214 </td>
   <td style="text-align:right;"> 0.8833873 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> readr </td>
   <td style="text-align:right;"> 4.807779 </td>
   <td style="text-align:right;"> 4.450297 </td>
   <td style="text-align:right;"> 3.970501 </td>
   <td style="text-align:right;"> 20.70830 </td>
   <td style="text-align:right;"> 1.5432615 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> base </td>
   <td style="text-align:right;"> 8.758645 </td>
   <td style="text-align:right;"> 8.396993 </td>
   <td style="text-align:right;"> 7.747258 </td>
   <td style="text-align:right;"> 25.51482 </td>
   <td style="text-align:right;"> 1.4263080 </td>
  </tr>
</tbody>
</table>

The faster function is still `data.table::fread` with a mean reading time of about ~1 ms,  followed by `pandas` (4.35 ms) and `readr` (4.81 ms). The R base function `read.csv` is the slowest, with reading times about 4-fold  larger than `data.table::fread`.

We could graphically visualize the `microbenchmark` performance just launching `autoplot(mb)` but that would not be fun! We come so far, why not visualize the data using `python`?

# Seaborn

First we need to convert the *R* object `mb` to `python` object.

```r
py$mb <- r_to_py(mb, convert = TRUE)
```

In what is dataframe converted in *R*?


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

ax = sns.boxplot(x="expr", y="time_ms", data = mb)

ax  = ax.set(ylabel='Time (milliseconds)', xlabel='package')

plt.show()
```

<img src="/post/2019-04-17-reticulate_files/figure-html/p_libraries-1.png" width="672" />

# Conclusion

In this sprint race to import csv in *R*, the first place is still hold by the favourite `data.table::fread` followed by `pandas read_csv` and then by `readr::read_csv`. These two last packages/functions were really close at the final line. The base `R` function `read.csv` was not able to get to the podium and had reading times about 4-fold larger than `data.table::fread`.

Ciao Ciao!

