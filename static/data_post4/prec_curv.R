# series of function for extracting curves using the precrec package that is BUGGED

```{r extract_rocpr}
get_rocpr <- function(mod, out = "curve", resp = "Yes"){
  
  if (!is(mod, "train")) stop("The object selected is not a model")
  
  # we get the predicition from the caret model
  df <- mod[["pred"]]
  
  # we insert scorese (probabilities) and observations and folds
  cvdat <-  mmdata(scores = df$Yes, labels = df$obs, posclass = resp, fold_col = df$Resample)
  
  # this calculate basic metrics as sensitivy, recall but ATTENTION: BUG in the package!!!!!!!!
  # https://goo.gl/Xp1d6t
  metrics_mod <-  data.frame(evalmod(cvdat, mode = "basic")) %>%
    mutate(modname = mod[["method"]])
  
  # this is to get the values of ROC and PRC curves
  dat_rocpr <- as.data.frame(evalmod(cvdat)) %>%
    mutate(modname = paste0(mod[["method"]],"-",mod[["metric"]]) )
  
  if (out == "curve")  return(dat_rocpr)
  if (out == "evalmod") return(evalmod(cvdat)) # this is in case we want to get 
  if (out == "metrics") return(metrics_mod) 
}

data_rocpr <- map_dfr(model_list, get_rocpr)

str(data_rocpr)

data_rocpr <- map_dfr(model_list, get_rocpr)

data_rocpr  %>% 
  filter(type == "PRC") %>% 
  mutate(modname = factor(modname, levels = mod_names)) %>% 
  ggplot(aes(y = y, x = x, col = modname)) +
  geom_line() +
  geom_abline(slope = 0, intercept = 0.0479, linetype = 2) + # this is the probability of  "Yes" 
  geom_abline(slope = 0, intercept = 0.1176136, linetype = 1) + # this is the probability of  "Yes" 
  labs( y = "Precision TP/(TP+FP)",
        x = "Recall TP/(TP+FN)",
        title = "Precision-Recall Curve")
