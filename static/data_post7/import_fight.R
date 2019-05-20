# Baltimore 2019
# function to import obervations of fights
# and modified radar plot that has argument angle

# libraries----------
library(tidyverse)
library(vroom)
library(svDialogs)
library(readr)
library(janitor)
library(ggthemes)
library(scales)
library(lubridate)
library(RSQLite)
library(fmsb)
library(purrr)

import_fight <- function(link_file,
                         rd_n = 3, 
                         link_db = "/Users/heverz/Documents/R_projects/muaydata/static/data_post7/one_db.sqlite",
                         write_db = FALSE){
  # function to import fight as in BORIS output
  
  date_subj<- read_tsv(link_file, n_max = 7, col_names = FALSE, skip_empty_rows = TRUE) %>% 
    {
      date_f <- .$X2[7]
      subject <- .$X2[1]
      cbind(date_f, subject)
    }
  
  f1 <- read_tsv(link_file , skip = 15) %>%   
    clean_names() %>%
    remove_empty(c("rows", "cols")) %>% 
    mutate(subject = date_subj[2], date_f = date_subj[1] ) %>% 
    separate(subject, sep = "\\.", c("fighter", "opponent")) %>% #name_lastname.name_lastname
    rename(lead_back = modifier_1, landed = modifier_2) %>% 
    select(- c("media_file_path", "fps", "status", "total_length")) 
  
  # dataframe containing 2 cols: beh_mod and corresponding 
  # beh_def (that stands for beh_def...inition). Used for recoding. 
  # example: front_rear_kick is a push kick
  beh_recode <- read_csv("/Users/heverz/Documents/R_projects/muaydata/static/data_post7/beh_recode.csv")
  
  # this is used to create labels for rounds
  rds <- paste0( rep("r", rd_n), 1:rd_n)
  
  # extract indexes of the end of the round
  to_subset<- map_dbl(rds, function(rd, df=f1) {
    tail(which(df[["behavior"]] == rd), 1) 
  })
  
  # add a column called rnd that indicates round number
  # recode "None"
  # unite 3 columns for left_join
  f1_2 <- f1 %>% 
    mutate(rown = 1:nrow(.)) %>% 
    mutate(rnd = cut(rown, breaks = c(0, to_subset), labels = rds), date_f = date_f) %>% 
    filter(!behavior %in% rds) %>% 
    select(-rown)%>% 
    mutate(lead_back = replace(lead_back, lead_back == "None", "lead")) %>%
    mutate(landed = replace(landed, landed == "None", "not_landed"))  %>%
    separate(behavior, c("behavior", "target_hit")) %>% 
    unite( "beh_mod", behavior, behavioral_category, lead_back, remove = FALSE) %>%
    left_join(., beh_recode) %>% 
    rename(beh_original = behavior, category = behavioral_category, beh_categ_lead= beh_mod) 
  
  
  if(write_db == TRUE) {
    mydb <- dbConnect(RSQLite::SQLite(), "/Users/heverz/Documents/R_projects/muaydata/static/data_post7/one_db.sqlite")
    dbWriteTable(mydb, "one_GP", f1_2, append = TRUE)
    dbDisconnect(mydb)
  } 
  return(f1_2)
}


rad2 <- function (df, axistype = 0, seg = 4, pty = 16, pcol = 1:8, plty = 1:6, 
                  plwd = 1, pdensity = NULL, pangle = 45, pfcol = NA, cglty = 3, 
                  cglwd = 1, cglcol = "navy", axislabcol = "blue", title = "", 
                  maxmin = TRUE, na.itp = TRUE, centerzero = FALSE, vlabels = NULL, 
                  vlcex = NULL, caxislabels = NULL, calcex = NULL, paxislabels = NULL, 
                  palcex = NULL, angle = 0, ...) 
{
  if (!is.data.frame(df)) {
    cat("The data must be given as dataframe.\n")
    return()
  }
  if ((n <- length(df)) < 3) {
    cat("The number of variables must be 3 or more.\n")
    return()
  }
  if (maxmin == FALSE) {
    dfmax <- apply(df, 2, max)
    dfmin <- apply(df, 2, min)
    df <- rbind(dfmax, dfmin, df)
  }
  plot(c(-1.2, 1.2), c(-1.2, 1.2), type = "n", frame.plot = FALSE, 
       axes = FALSE, xlab = "", ylab = "", main = title, asp = 1, 
       ...)
  theta <- seq((90 + angle), (450 + angle), length = n + 1) * pi/180
  theta <- theta[1:n]
  xx <- cos(theta)
  yy <- sin(theta)
  CGap <- ifelse(centerzero, 0, 1)
  for (i in 0:seg) {
    polygon(xx * (i + CGap)/(seg + CGap), yy * (i + CGap)/(seg + 
                                                             CGap), lty = cglty, lwd = cglwd, border = cglcol)
    if (axistype == 1 | axistype == 3) 
      CAXISLABELS <- paste(i/seg * 100, "(%)")
    if (axistype == 4 | axistype == 5) 
      CAXISLABELS <- sprintf("%3.2f", i/seg)
    if (!is.null(caxislabels) & (i < length(caxislabels))) 
      CAXISLABELS <- caxislabels[i + 1]
    if (axistype == 1 | axistype == 3 | axistype == 4 | axistype == 
        5) {
      if (is.null(calcex)) 
        text(-0.05, (i + CGap)/(seg + CGap), CAXISLABELS, 
             col = axislabcol)
      else text(-0.05, (i + CGap)/(seg + CGap), CAXISLABELS, 
                col = axislabcol, cex = calcex)
    }
  }
  if (centerzero) {
    arrows(0, 0, xx * 1, yy * 1, lwd = cglwd, lty = cglty, 
           length = 0, col = cglcol)
  }
  else {
    arrows(xx/(seg + CGap), yy/(seg + CGap), xx * 1, yy * 
             1, lwd = cglwd, lty = cglty, length = 0, col = cglcol)
  }
  PAXISLABELS <- df[1, 1:n]
  if (!is.null(paxislabels)) 
    PAXISLABELS <- paxislabels
  if (axistype == 2 | axistype == 3 | axistype == 5) {
    if (is.null(palcex)) 
      text(xx[1:n], yy[1:n], PAXISLABELS, col = axislabcol)
    else text(xx[1:n], yy[1:n], PAXISLABELS, col = axislabcol, 
              cex = palcex)
  }
  VLABELS <- colnames(df)
  if (!is.null(vlabels)) 
    VLABELS <- vlabels
  if (is.null(vlcex)) 
    text(xx * 1.2, yy * 1.2, VLABELS)
  else text(xx * 1.2, yy * 1.2, VLABELS, cex = vlcex)
  series <- length(df[[1]])
  SX <- series - 2
  if (length(pty) < SX) {
    ptys <- rep(pty, SX)
  }
  else {
    ptys <- pty
  }
  if (length(pcol) < SX) {
    pcols <- rep(pcol, SX)
  }
  else {
    pcols <- pcol
  }
  if (length(plty) < SX) {
    pltys <- rep(plty, SX)
  }
  else {
    pltys <- plty
  }
  if (length(plwd) < SX) {
    plwds <- rep(plwd, SX)
  }
  else {
    plwds <- plwd
  }
  if (length(pdensity) < SX) {
    pdensities <- rep(pdensity, SX)
  }
  else {
    pdensities <- pdensity
  }
  if (length(pangle) < SX) {
    pangles <- rep(pangle, SX)
  }
  else {
    pangles <- pangle
  }
  if (length(pfcol) < SX) {
    pfcols <- rep(pfcol, SX)
  }
  else {
    pfcols <- pfcol
  }
  for (i in 3:series) {
    xxs <- xx
    yys <- yy
    scale <- CGap/(seg + CGap) + (df[i, ] - df[2, ])/(df[1, 
                                                         ] - df[2, ]) * seg/(seg + CGap)
    if (sum(!is.na(df[i, ])) < 3) {
      cat(sprintf("[DATA NOT ENOUGH] at %d\n%g\n", i, df[i, 
                                                         ]))
    }
    else {
      for (j in 1:n) {
        if (is.na(df[i, j])) {
          if (na.itp) {
            left <- ifelse(j > 1, j - 1, n)
            while (is.na(df[i, left])) {
              left <- ifelse(left > 1, left - 1, n)
            }
            right <- ifelse(j < n, j + 1, 1)
            while (is.na(df[i, right])) {
              right <- ifelse(right < n, right + 1, 1)
            }
            xxleft <- xx[left] * CGap/(seg + CGap) + 
              xx[left] * (df[i, left] - df[2, left])/(df[1, 
                                                         left] - df[2, left]) * seg/(seg + CGap)
            yyleft <- yy[left] * CGap/(seg + CGap) + 
              yy[left] * (df[i, left] - df[2, left])/(df[1, 
                                                         left] - df[2, left]) * seg/(seg + CGap)
            xxright <- xx[right] * CGap/(seg + CGap) + 
              xx[right] * (df[i, right] - df[2, right])/(df[1, 
                                                            right] - df[2, right]) * seg/(seg + CGap)
            yyright <- yy[right] * CGap/(seg + CGap) + 
              yy[right] * (df[i, right] - df[2, right])/(df[1, 
                                                            right] - df[2, right]) * seg/(seg + CGap)
            if (xxleft > xxright) {
              xxtmp <- xxleft
              yytmp <- yyleft
              xxleft <- xxright
              yyleft <- yyright
              xxright <- xxtmp
              yyright <- yytmp
            }
            xxs[j] <- xx[j] * (yyleft * xxright - yyright * 
                                 xxleft)/(yy[j] * (xxright - xxleft) - xx[j] * 
                                            (yyright - yyleft))
            yys[j] <- (yy[j]/xx[j]) * xxs[j]
          }
          else {
            xxs[j] <- 0
            yys[j] <- 0
          }
        }
        else {
          xxs[j] <- xx[j] * CGap/(seg + CGap) + xx[j] * 
            (df[i, j] - df[2, j])/(df[1, j] - df[2, j]) * 
            seg/(seg + CGap)
          yys[j] <- yy[j] * CGap/(seg + CGap) + yy[j] * 
            (df[i, j] - df[2, j])/(df[1, j] - df[2, j]) * 
            seg/(seg + CGap)
        }
      }
      if (is.null(pdensities)) {
        polygon(xxs, yys, lty = pltys[i - 2], lwd = plwds[i - 
                                                            2], border = pcols[i - 2], col = pfcols[i - 
                                                                                                      2])
      }
      else {
        polygon(xxs, yys, lty = pltys[i - 2], lwd = plwds[i - 
                                                            2], border = pcols[i - 2], density = pdensities[i - 
                                                                                                              2], angle = pangles[i - 2], col = pfcols[i - 
                                                                                                                                                         2])
      }
      points(xx * scale, yy * scale, pch = ptys[i - 2], 
             col = pcols[i - 2])
    }
  }
}


             