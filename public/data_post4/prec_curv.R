get_pr <- function(mod) {
  mod[["pred"]][["obs"]] <- mod[["pred"]][["obs"]] %>% 
    recode(Yes = 1, No = 0)
  
  pr_data <- pr.curve(scores.class0 = mod[["pred"]][["obs"]], 
                      weights.class0 = mod[["pred"]][["Yes"]], curve = TRUE)  # prec curve using the predition and observations of the model
  pr_data <-  as.data.frame(pr_data$curve[,1:2]) %>% 
    rename( "Precision" = V2, "Recall" = V1) %>% 
    mutate(model = mod[["method"]])
}  



pr_data$curve  %>% 
  as.data.frame() %>% 
  rename( "Precision" = V2, "Recall" = V1) %>% 
  ggplot(aes(y = Precision, x = Recall)) +
  geom_line() +
  geom_abline(slope = 0, intercept = 4.79/ 100, linetype = 2) +
  labs( y = "Precision TP/(TP+FP)",
        x = "Recall TP/(TP+FN)")

table(mod_ranger$pred$pred)



# METRICS
resamps <- resamples(model_list)

resamps$values %>% 
  gather("model~metric", "value", 2:13) %>%  # from wide to long format
  separate ("model~metric", c("model", "metric")) %>%  # separate columns
  mutate(model = factor(model, levels = c("glmnet", "rpart", "ctree", "rf"))) %>% 
  mutate(metric = recode(metric, Sens = "Sensitivity", Spec = "Specificity")) %>% 
  group_by(model, metric) %>% 
  summarize(mean = mean(value), sd = sd(value)) %>% 
  # mutate(metric = factor(metric, levels = c("ROC", "Sensitivity", "Specificity"))) %>% 
  
  
  ggplot(aes(y= mean, x = model, col = model)) +
  geom_point(size = 2.5) +
  geom_errorbar(aes(ymin = mean - sd, ymax =  mean + sd), width = 0.1) +
  scale_y_continuous(limits = c(0, 1)) + 
  coord_flip() +
  facet_wrap(metric ~ .) +
  theme(legend.position = "none")

get_rocpr <- function(mod, out = "curve", resp = "Yes"){
  
  if (!is(mod, "train")) stop("The object selected is not a model")
  
  # we get the predicition from the caret model
  df <- mod[["pred"]]
  
  # we insert scorese (probabilities) and observations and folds
  cvdat <-  mmdata(scores = df$Yes, labels = df$obs, posclass = resp, fold_col = df$Resample)
  
  # this in thepry calculate basic metrics as sensitivy, recall but ATTENTION: BUG in the package!!!!!!!!
  # it would have been a great code-saver
  # https://goo.gl/Xp1d6t 
  metrics_mod <-  data.frame(evalmod(cvdat, mode = "basic")) %>%
    mutate(modname = mod[["method"]])
  
  # this is to get the values of ROC and PRC curves
  dat_rocpr <- as.data.frame(evalmod(cvdat)) %>%
    mutate(modname = paste0(mod[["method"]],"-",mod[["metric"]]))
  
  if (out == "curve")  return(dat_rocpr) # this is for the curves
  if (out == "evalmod") return(evalmod(cvdat)) # this is in case we want to get the evaluated model
  if (out == "metrics") return(metrics_mod)  # this is if we want the metrics (but BUG in the package)
}
