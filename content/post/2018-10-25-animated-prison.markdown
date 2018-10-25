---
title: Animated Prison
author: ~
date: '2018-10-25'
slug: animated-prison
categories: 
  - R
tags: 
  - av
  - ggplot
  - visualization
lastmod: '2018-10-23T18:19:53-04:00'
keywords: []
description: 'Visualization changes in prison population (post3)'
comment: yes
toc: yes
autoCollapseToc: no
contentCopyright: no
reward: no
mathjax: no
---
In this post we will get the datasets and write the code to create the following visualization of the rate of incarceration over time in U.S (custody and jurisdiction counts of all prisoners). 

*[Double click for full screen]*

<iframe title="Prison_video" height="400" src="/data_post3/output.mp4" frameBorder="0" allowfullscreen></iframe>


<!--more-->

What are we looking at? The video-graph represents the number of people in private and public prisons (sentenced and unsentenced) normalized by the corresponding state population. The darker is a state, the higher is the prison population relative to the total population. The year is indicate on the top left and the video shows the data __from 1999 to 2015__. 

Some changes are quite evident. For example, Texas is the darkest among Southern states at the start of the video, but by the year 2015 it is Oklahoma to lead the South in terms of prison population.

If you liked the video/graph and you are interested in the code behind that visualization keep reading!

If not, __bye bye!__

# Introduction

Animated plot are like spinning-back kicks in muay Thai: they are extremely risky, seldom used, but they can be highly effective and hit you right between the eyes!

<center>
![prova](/data_post3/giphy.gif)
</center>

Few weeks ago I stumble upon a newly released package, [*av*](https://github.com/ropensci/av) that uses [*ffmpeg*](https://ffmpeg.org/) to capture *R* plots and create videos. 
I decided to give it a try and use it with heat-maps to visualize the change of prison population in U.S. 
Admittedly the video does not knock you out (changes are relatively small), but I think that it does still summarize the data at glance quite well.


# Get the data and make it tidy

We load the libraries.

```r
library(av)
library(lubridate)
library(maps)
library(readr)
library(readxl)
library(stringr)
library(tidyverse)
library(transformr)
```

The primary dataset that we are going to use is the [National Prisoner Statistics, 1978-2015](https://www.icpsr.umich.edu/icpsrweb/ICPSR/studies/36657) curated by the United States Department of Justice, the Office of Justice Program and the Bureau of Justice Statistics. 

The dataset (*rda file*) comes with many documents including the Codebook and details of the methodology used to collect the data. We double click on the *rda* file to import it, we assign it to *prison_pop* and we take a look at the some rows and columns.





```r
prison_pop <- as_tibble(da36657.0001)
prison_pop[2044:2052, 1:6]
```

```
## # A tibble: 9 x 6
##    YEAR STATEID                  STATE REGION              CUSGT1M CUSGT1F
##   <dbl> <fct>                    <fct> <fct>                 <dbl>   <dbl>
## 1  2015 (50) 50. Vermont         VT    (1) Northeast           966      83
## 2  2015 (51) 51. Virginia        VA    (3) South             28105    2325
## 3  2015 (53) 53. Washington      WA    (4) West              15848    1297
## 4  2015 (54) 54. West Virginia   WV    (3) South              5319     606
## 5  2015 (55) 55. Wisconsin       WI    (2) Midwest           20346    1329
## 6  2015 (56) 56. Wyoming         WY    (4) West               1888     245
## 7  2015 (60) State prison total  ST    (7) State total     1054949   78954
## 8  2015 (70) US prison total (s… US    (5) U.S. total      1192289   89180
## 9  2015 (99) Federal BOP         FE    (6) Federal Bureau…  137340   10226
```

The data is in the right format (long) but it is not tidy. For example, the last 3 observations are totals that we don't need and the name of the states (*STATEID*) is recorder with other superfluous information. We need to cleaning it up and also restrict our focus of analysis.

I decided to look at the variables that indicate the number of inmates in custody (private and public facilities). The Codebook says:

__*"Variables CNOPRIVM, CNOPRIVF, CWPRIVM, and CWPRIVF were created by BJS starting in 1999 to address the fact that some states were counting their private prisons in their custody counts, but others were not."*__

So we are going to get those variables, filter the dataframe/tibble to have years from 1999 to 2015 and clean up the STATEID column.


```r
prison_1999 <-
  prison_pop %>% 
  filter(YEAR >= 1999, !str_detect(STATEID, 'total|BOP')) %>% # remove totals
  select(YEAR, STATE, STATEID, matches('PRIV.$'))  # lets take the variables regarding the people in costudy

prison_1999$STATEID <- tolower(str_sub(prison_1999$STATEID, 10, -1)) # clean up the STATEID column
```

We calculate the totals (male + females, private only,  public facilities..).

```r
# calculate the total prison population  by state
prison_1999_tot <- 
  prison_1999 %>% 
  rowwise() %>%  # I love this function
  mutate(TOT = CWPRIVM + CWPRIVF, 
         TOT_PUB = CNOPRIVM + CNOPRIVF, 
         TOT_PRIV =  TOT - TOT_PUB) %>% 
  ungroup() %>% 
  group_by(YEAR, STATEID, STATE) %>% 
  summarize(PRIS = sum(TOT, na.rm = TRUE), 
            PRIS_PUB = sum(TOT_PUB, na.rm = TRUE),
            PRIS_PRIV = sum(TOT_PRIV, na.rm = TRUE)) 
```

..and this is what we obtain:

```r
glimpse(prison_1999_tot)
```

```
## Observations: 867
## Variables: 6
## $ YEAR      <dbl> 1999, 1999, 1999, 1999, 1999, 1999, 1999, 1999, 1999...
## $ STATEID   <chr> "alabama", "alaska", "arizona", "arkansas", "califor...
## $ STATE     <fct> AL, AK, AZ, AR, CA, CO, CT, DE, DC, FL, GA, HI, ID, ...
## $ PRIS      <dbl> 21227, 3916, 25986, 10388, 160687, 12995, 16987, 658...
## $ PRIS_PUB  <dbl> 21227, 2529, 24594, 9174, 156066, 12995, 16987, 6585...
## $ PRIS_PRIV <dbl> 0, 1387, 1392, 1214, 4621, 0, 0, 0, 4024, 3773, 3001...
```

But now we have our first problem: a possible increase in the prison population might be the result of corresponding variation of U.S population. To circumvent that problem we need to express the prison population relative to the corresponding state population for the time interval of interest. Where do we get the data? 
In the website of the U.S Census Bureau, of course!

In particular this is what we need: 

* [Intercensal Tables form 1990 to 2000](https://www.census.gov/data/tables/time-series/demo/popest/intercensal-1990-2000-state-and-county-totals.html)

* [Intercensal Tables form 2000 to 2010](https://www.census.gov/content/census/en/data/tables/time-series/demo/popest/intercensal-2000-2010-state.html)

* [State Population by Characteristics: 2010-2017](https://www.census.gov/content/census/en/data/tables/2017/demo/popest/state-detail.html)

I have already merged all the census data together in *csv* file that is on the cloud and we will assign to *sp_wide* (it is in wide format).


```r
# Thanks LukeA: https://stackoverflow.com/questions/33135060/read-csv-file-hosted-on-google-drive#33142446) 

ids <-  "1bCGjAtCjoRuRf8RFw78Rzjtq_r5uxXBP" # IDS file 

sp_wide <- read_csv(sprintf("https://drive.google.com/uc?id=%s&export=download", ids))
```

We need to make the STATEID column consistent with the dataframe/tibble of the prison population and to rearrange it in a long format.

```r
sp_long <- sp_wide %>% 
  mutate(STATEID = tolower(STATEID)) %>% 
  gather(YEAR, POP, -STATEID, convert = TRUE, na.rm = TRUE) %>% 
  na.omit()
```

Finaly we can join the 2 dataframe/tibble by STATEID and YEAR and normalize the prison data by state population.

```r
prison_norm <- 
  left_join(prison_1999_tot, sp_long, by = c("STATEID", "YEAR")) %>% 
  rowwise() %>% 
  mutate(PERC_PRIS = PRIS/POP *10000) %>% 
  ungroup()
```

# Plot it!

What is a map? It is a series of polygons that have been drawn on a paper sheet based on known latitude and longitude.

In our case the sheet of paper is the area within our Cartesian axes, and latitude and longitude are X and Y coordinates. We need those coordinates to draw our map. Easy done!
We use the package [*maps*](https://cran.r-project.org/web/packages/maps/index.html) to get the coordinates of each U.S. state and then we merge the obtain dataframe/tibble with the one of the prison population.


```r
states <- map_data("state") %>% 
  rename(STATEID = region)

prison_norm_xy <- 
  left_join(prison_norm, states, by = "STATEID") %>% 
  select(YEAR:lat) %>% 
  setNames(toupper(names(.)))

glimpse(prison_norm_xy)
```

```
## Observations: 264,163
## Variables: 10
## $ YEAR      <dbl> 1999, 1999, 1999, 1999, 1999, 1999, 1999, 1999, 1999...
## $ STATEID   <chr> "alabama", "alabama", "alabama", "alabama", "alabama...
## $ STATE     <fct> AL, AL, AL, AL, AL, AL, AL, AL, AL, AL, AL, AL, AL, ...
## $ PRIS      <dbl> 21227, 21227, 21227, 21227, 21227, 21227, 21227, 212...
## $ PRIS_PUB  <dbl> 21227, 21227, 21227, 21227, 21227, 21227, 21227, 212...
## $ PRIS_PRIV <dbl> 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0...
## $ POP       <dbl> 4430141, 4430141, 4430141, 4430141, 4430141, 4430141...
## $ PERC_PRIS <dbl> 47.91495, 47.91495, 47.91495, 47.91495, 47.91495, 47...
## $ LONG      <dbl> -87.46201, -87.48493, -87.52503, -87.53076, -87.5708...
## $ LAT       <dbl> 30.38968, 30.37249, 30.37249, 30.33239, 30.32665, 30...
```

In our video/graph we want also to indicate the state code (2 letters). To do that we need to create a dataframe/tibble that has the coordinates of the positions of those labels. Ideally, they would be in the center of the state, so we can just average the longitude and latitude of each state. Of course don't expect that to be perfect, the shape of states is not a perfect square or circle!

```r
xy_lab <- 
  prison_norm_xy %>% 
  filter(STATEID != "district of columbia") %>% 
  ungroup() %>% 
  group_by(STATEID, STATE) %>% 
  summarize(LAB_LONG = mean(LONG), LAB_LAT = mean(LAT)) %>% 
  mutate(LAB_LONG = replace(LAB_LONG, STATE == "FL", LAB_LONG + 1.7))  # to adjust FL label
```

District of Columbia is too small to be seen in the map. Let's remove it.

```r
data_p <- 
  prison_norm_xy %>% 
  filter(STATEID != "district of columbia") 
```

Finally, we get to the code to make the video. The idea behind it is pretty simple. We write a function that split our dataframe by year and plots sequentially each of the yearly data. Than we call the function and we capture the output with *av*. A video is just a sequence of single images!


```r
makeplot <- function(){
  datalist <- split(data_p, data_p$YEAR)
  map(datalist, function(x){
    p <- 
      ggplot(x) +
      geom_polygon(aes(LONG, LAT, fill = PERC_PRIS, group = STATEID), colour = "white") +
      scale_fill_gradient(low = "white", high = "black", limit = c(0, 100)) +
      geom_text(aes(LAB_LONG, LAB_LAT, label = STATE), color = "white", size=3, data = xy_lab) +  # here our labels
      labs(title = "Prison Population (every 10 thousand)",
           subtitle = paste0("YEAR: ", x$YEAR[1]),
           fill = " ") +
      theme_void() +
      theme(plot.title = element_text(hjust = 0.5),
            legend.title.align = 0.5,
            panel.background = element_rect(fill = "slategray1"),
            plot.background = element_rect(fill = "slategray1"))

    print(p)
  })
}

video_file <- file.path("~/Documents", 'output.mp4')
av::av_capture_graphics(makeplot(), video_file, 1600, 900, res = 144, framerate = 2)
av::av_video_info(video_file)
utils::browseURL(video_file)
```

With that we have covered all the code related to the video/graph, but I could not resist... 


<center>
![prova](/data_post3/columbo.jpeg)
</center>

...making at least another plot.

# A simple line plot

I wanted also to create a classic line plot with the U.S total prison population (1999-2015) and also indicate the party of the president in office (as Harvey Wickam as done in his ggplot2 book).

Let's get the presidents...

```r
pres_sub <- 
  presidential %>% 
  mutate(start = year(start), end = year(end)) %>% 
  top_n(3, end)

pres_sub$start[1] <- 1999
```

and the plot!

```r
prison_norm_tot <-
  prison_norm %>% 
  filter(STATEID != "district of columbia") %>% 
  group_by(YEAR) %>% 
  summarize(PRIS = sum(PRIS), 
            PRIS_PUB = sum(PRIS_PUB),
            PRIS_PRIV = sum(PRIS_PRIV), 
            POP = sum(POP),
            PERC_PRIS = PRIS/POP,
            PERC_PRIS_PUB = PRIS_PUB/POP,
            PERC_PRIS_PRIV = PRIS_PRIV/POP)

ggplot(prison_norm_tot) +
  labs(title = "Number of people in prison (every 10 thousand)",
  y = "",
  x = "Year",
  caption = "fig.2") +
  geom_rect(aes(xmin = start, xmax = end, fill = party), ymin = -Inf, ymax = Inf, alpha = 0.2,
  data = pres_sub) +
  scale_fill_manual(values = c("blue","red")) +
  geom_line(aes(YEAR, PERC_PRIS * 10000)) +
  scale_x_continuous(expand = c(0, 0), labels = 1999:2015, breaks = 1999:2015) +
  theme(plot.title = element_text(hjust = 0.5),
        axis.text.x = element_text(angle = 45, hjust = 1))
```

<img src="/post/2018-10-25-animated-prison_files/figure-html/fig.2_prison_time-1.png" width="672" />

From 2008 to 2015 the prison population went from about 44 inmates for 10 thousand people to about 39. It is ≈ 10% decrease!
That is going to be the last graph of the post!

Next time, I will try to focus on machine learning analysis.



