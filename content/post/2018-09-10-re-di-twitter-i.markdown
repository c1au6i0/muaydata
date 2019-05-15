---
title: Il Re di Twitter? (PARTE I)
author: C1au6i0_HH
date: "2018-09-12"
slug: re-di-twitter-i
categories:
  - R
tags:
  - R
  - twitteR
  - twitter
  - ggplot
  - textmining
comment: yes
toc: yes
autoCollapseToc: no
contentCopyright: no
reward: no
mathjax: no
---
In questa serie di Posts andremo ad analizzare gli ultimi 3200 tweets di Di Maio, Salvini e Martina. Il mio studio sarà diviso in 2 parti:

* Nella __parte I__ analizzeremo le abitudini dei 3 leader e  scopriremo chi dei 3 è il più attivo, quando durante la giornata, quanto sono popolari i vari tweets e molte altre informazioni.
* Nella __parte II__ ci addentreremo nel contenuto dei tweets e andremo a vedere quali sono le parole e i lemmi più usati dai 3 politici.

<!--more-->
# Premessa

Social media come Twitter sono diventati anche in Italia uno dei mezzi di comunicazione più usati dai politici per rivolgersi direttamente al loro elettorato. Una quantità di informazioni enorme su abitudini, messaggio elettorale e tipo di elettori si nasconde tra quei tweets di poche centinaia di byte. Un famoso post di [David Robinson](http://varianceexplained.org/r/trump-tweets/) ha dimostrato come queste informazioni possono essere scovate dall'occhio attento del Data Scientist attraverso l'uso sapiente *R* e alcuni sui pacchetti ([*twitteR*](https://cran.r-project.org/web/packages/twitteR/index.html), *tidyverse* e *tidytext*).

Eccomi qui perciò anche io, munito di *R*, *RStudio* e computer con l'obiettivo di __esplorare__ e __comparare__ i __tweets dei leader dei 3 [maggiori](https://it.wikipedia.org/wiki/Partiti_politici_italiani#Partiti_principali) partiti italiani__ (leader in ordine alfabetico per username Twitter):

* Movimento a 5 stelle: Luigi Di Maio (luigidimaio).
* Lega: Matteo Salvini (matteosalvinimi).
* Partito Democratico: Maurizio Martina (maumartina).

I posts saranno densi di codice (dopo tutto sto facendo tutto questo anche per rimanere un attivo *R user*) ma inserirò delle conclusioni con i punti chiave dell'analisi.

# Analisi
## Preparazione e download dati

Per avere accesso a Twitter su *R* è necessario come prima cosa creare una app su Twitter. Michael Galarnyk ha creato un ottimo tutorial che dà istruzioni passo per passo per completare questa prima fase ([guida di Michael Galarnyk](https://medium.com/@GalarnykMichael/accessing-data-from-Twitter-api-using-r-part1-b387a1c7d3e)). 
Una volta creata la app, il pacchetto *twitteR* ci permetterà di accedere all'API e lavorare con *R* sui dati ottenuti.

Iniziamo con il caricare *twitteR* e una serie di altre librerie che ci saranno utili successivamente.

```r
library("twitteR")
library("ggridges")
library("gridExtra")
library("lubridate")
library("RSQLite") # I save the data in a database
library("scales")
library("tidyverse")
```





Ci autentichiamo utilizzando le chiavi ottenute seguendo la [guida di Michael Galarnyk](https://medium.com/@GalarnykMichael/accessing-data-from-twitter-api-using-r-part1-b387a1c7d3e).

```r
library("twitteR")

API_key <- 	"XXX"
API_secret <- "XXX"
access_token <- "XXX"
access_secret <- "XXX"

setup_twitter_oauth(API_key, API_secret, access_token, access_secret)
```

Otteniamo i 3200 tweets di luigidimaio, maumartina, matteosalvinimi usando il comando *userTimeline* e diamo una pulita al dataframe (twdat = tweets data) ottenuto.

```r
pol <- list("luigidimaio", "matteosalvinimi", "maumartina")

twdat <- as_tibble(map_dfr(pol, function(x) twListToDF(userTimeline(x, includeRts = TRUE, 
    n = 3200))))


twdat$statusSource <- str_extract(twdat$statusSource, "iPhone|Web Client|Android|TweetDeck|iPad|Hootsuite|Facebook|IoResto|Websites|IFTTT|Instagram|iOS|Periscope")  # this is to extract the important info

twdat$created <- with_tz(twdat$created, "CET")  # time-zone
```

OK, abbiamo a questo punto un dataframe/tibble con cui possiamo lavorare.

<!-- Database -->


## QuanTo twittano

Iniziamo con il vedere chi è il più attivo tra i tre e numero di tweets al giorno attraverso differenti misure di tendenza centrale.

```r
daily_tw <- twdat %>% 
   count(screenName, round_date(created, "day")) %>% 
   group_by(screenName) %>% 
   dplyr::summarize(max = max(n),
                    min = min (n),
                    IQR = IQR(n),
                    mean = round(mean(n),0), 
                    meadian = median(n),
                    mode = names(sort(-table(n)))[1],
                    St_Dev = sd(n)
                    ) 
knitr::kable(daily_tw, align = "ccccc", caption = "tab.1: Daily Tweets")
```



|   screenName    | max | min | IQR | mean | meadian | mode |  St_Dev   |
|:---------------:|:---:|:---:|:---:|:----:|:-------:|:----:|:---------:|
|   luigidimaio   | 54  |  1  |  2  |  3   |    2    |  1   | 3.559438  |
| matteosalvinimi | 93  |  2  |  9  |  12  |    8    |  5   | 11.192814 |
|   maumartina    | 24  |  1  |  2  |  2   |    2    |  1   | 1.840639  |

__Salvini è di gran lunga il più attivo__,  4-6 volte più di Di Maio e di Martina. Salvini è riuscito a pubblicare un massimo di 93 tweets in un giorno (2018-02-25), ma tipicamente (moda) pubblica 5 tweets al giorno e una media di 12 tweets al giorno (la distribuzione è chiaramente positive skewed). Martina e Di Maio tendono ad utilizzare con simile frequenza Twitter ma Di Maio tende ad essere più variabile (vedi range e St_Dev).

__Salvini è dei tre l'unico che pubblica quasi esclusivamente materiale originale__. __Circa un terzo dei tweets di Di Maio e un quarto di quelli di Martina sono invece retweets__ (tab.2 sottostante).


```r
retw <-twdat %>%
  group_by(screenName) %>%
  summarize( tot_retw = sum(isRetweet), perc_retw = percent(tot_retw/n()))

knitr::kable(retw, align = "ccc", caption = "tab.2: Percent of retweets")
```



|   screenName    | tot_retw | perc_retw |
|:---------------:|:--------:|:---------:|
|   luigidimaio   |   1153   |   36.1%   |
| matteosalvinimi |    92    |   2.88%   |
|   maumartina    |   802    |   25.1%   |

## QuanDo twittano

### Ora e giorno della settimana

Andiamo ora a vedere il pattern con il quale i nostri 3 politici twittano e in particolare l'ora e giorno della settimana. I dati verranno espressi come percentuale dei tweets calcolati per ogni politico.

Il codice sottostante serve a creare il primo grafico.

```r
# this creates the plots of tweets by hours
theme_set(theme_grey())
tw_h <- twdat %>% 
  
  count(screenName, h = hour(created)) %>% 
  group_by(screenName) %>% 
  mutate(perc_h = n/sum(n)) %>% 
    
  ggplot(aes(h, 
             perc_h,
             group = screenName, 
             color = screenName)) +
  geom_line() +
  geom_point(size = 2.5) +
  scale_y_continuous(labels = percent_format()) +
  scale_color_manual(values = c("#FFC125","#00BA38","#F8766D")) +
  labs(x = "Hour of day (CET)",
       y = "",
       color = "",
       title = "",
       caption = "  ") +
  theme(legend.position = c(0.85,0.92), legend.background = element_blank(), legend.key = element_blank())
```


Qui creiamo il secondo grafico e plottiamo entrambi i grafici utilizzando il pacchetto *extraGrid*.

```r
# this create the plot of tweets by weekday
tw_d <- twdat %>% 
  
  count(screenName, w = wday(created, label = TRUE)) %>% 
  group_by(screenName) %>% 
  mutate(perc_d = n/sum(n)) %>% 
    
  ggplot(aes(factor(w, wday(c(2:7,1), label = TRUE)), 
             perc_d,
             group = screenName, 
             color = screenName)) +
  geom_line() +
  geom_point(size = 2.5) +
  scale_color_manual(values = c("#FFC125","#00BA38","#F8766D")) +
  scale_y_continuous(labels = percent_format()) +
  labs(x = "Day of the week",
       y = "",
       color = "",
       title = "",
       caption = "fig.1" ) +
  theme(legend.position = "none")

  # we use grid.arrange of the package gridExtra to assemble together the 2 plots 
  # we could have used the package cowplot too
  grid.arrange(tw_h, tw_d, ncol =  2, top = "Percentage of tweets          ")
```

<img src="/post/2018-09-10-re-di-twitter-i_files/figure-html/fig.1_plot_tw_wdays-1.png" width="960" />
__Salvini__ tende ad iniziare a twittare al mattino come Di Maio e Martina, ma  rispetto a loro, tende a continuare ad essere __attivo anche la sera (7-23)__. Per __Martina__ il picco di attività è __la mattina (9-11)__ mentre per __Di Maio è dalle 9 alle 16__ (fig.2, sinistra). __Tutti e tre i politici hanno un giorno durante il week-end in cui sono molto meno attivi__: sia per Di Maio che Salvini è il Sabato, mentre per Martina la Domenica (fig.2, destra).

Ho usato *ggridges*, una extention di *ggplot2*, per creare dei *density plots* e visualizzare in dettaglio l'interazione tra giorno della settimana ed ora del giorno dei tweets (fig.3 sottostante). L'analisi tende comunque a supportare la generabilità delle osservazioni precedenti ma con alcune precisazioni: la Domenica è Di Maio a distribuire i sui tweets  più tardi la sera. Inoltre, il Lunedì Salvini è, diversamente dagli altri giorni della settimana, molto più attivo nel primo pomeriggio tra le 14 e le 16 (fig.3). 


```r
twdat %>%
  ggplot(aes(hour(created), 
             factor(wday(created, label =TRUE), labels = wday(c( 1, 7:2), label = TRUE)),
             fill = screenName, 
             col  = screenName)) +
    geom_density_ridges(alpha = 0.2, scale = 1.2) +
    scale_y_discrete() +
    scale_x_continuous(limits = c(0,23), labels = seq(0,23,2), breaks = seq(0,23,2)) +
    scale_color_manual(values = c("#FFC125","#00BA38","#F8766D")) +
    coord_equal(ratio = 5) +
    labs(x = "Hour of day (CET)",
         y = NULL,
         color = NULL,
         caption = "fig.2",
         title = "Density of tweets during the day") +
    theme_ridges() + 
    theme(plot.title = element_text(face = "bold", hjust = 0.5),
          axis.title.x = element_text(hjust = 0.5)
                 ) +
    guides(fill = FALSE)
```

<img src="/post/2018-09-10-re-di-twitter-i_files/figure-html/fig.2_ridges-1.png" width="672" />

### Ultimi mesi

Gli ultimi mesi della politica italiana sono stati estremamente densi di eventi importanti, a partire dalle elezioni per poi proseguire con le  varie consultazioni e la formazione del governo. È perciò legittimo domandarsi se questa serie di avvenimenti abbia spinto i politici ad utilizzare più frequentemente Twitter per comunicare con i propri elettori.

Un caveat dei dati ottenuti è che *twitteR* non permette di scaricare più di 3200 tweets. Dal momento che Salvini è estremamente più attivo degli altri due politici, i suoi 3200 tweets sono stati pubblicati in un periodo inferiore rispetto a quelli di Di Maio e Martina (tab.3). 


```r
date_lim_screenName <- twdat %>%
  group_by(screenName) %>%   
  dplyr::summarize(first_tweet = min(created), last_tweet = max(created)) 

knitr::kable(date_lim_screenName , align = "cc",  caption = "tab.3: Interval of tweets")
```



|   screenName    |     first_tweet     |     last_tweet      |
|:---------------:|:-------------------:|:-------------------:|
|   luigidimaio   | 2014-09-09 17:47:51 | 2018-08-14 10:56:16 |
| matteosalvinimi | 2017-11-30 13:46:14 | 2018-08-26 19:35:21 |
|   maumartina    | 2014-02-19 11:40:18 | 2018-08-26 15:59:43 |





Per poter comparare l'attività dei 3 politici è necessario andare a monitorare lo stesso intervallo di tempo.

Il codice sottostante serve a trovare qual'è l'intervallo in mesi in cui disponiamo di dati per tutti e 3 i politici.
Andremo a plottare il seguente intervallo di tempo.


```r
date_lim <- twdat %>%
  group_by(screenName) %>%   
  dplyr::summarize(min_tw = ceiling_date(min(created), "month"), max_tw = floor_date(max(created) , "month")) %>% # we do approximate dates to have full months
  dplyr::summarize(min_shared = max(min_tw), max_shared = min(max_tw))

date_lim <- as_datetime(unlist(date_lim), tz = "CET")

knitr::kable(as_data_frame(date_lim) , align = "cc")
```

```
## Warning: `as_data_frame()` is deprecated, use `as_tibble()` (but mind the new semantics).
## This warning is displayed once per session.
```



|        value        |
|:-------------------:|
| 2017-12-01 01:00:00 |
| 2018-08-01 02:00:00 |

Creiamo quindi i grafici riguardanti il numero di tweets al mese per l'intervallo di Dicembre-Luglio.


```r
timeline_abs <- twdat %>% 
  mutate(month_r = floor_date(created, "month") ) %>%
  filter(created >= date_lim[1], created <= date_lim[2]) %>% 
  count(month_r, screenName) %>% 
  ggplot(aes(x = month_r, y = n,  group = screenName, col = screenName)) +
  geom_point( size = 2.5) +
  geom_line () +
  scale_x_datetime(labels = date_format("%Y %b"), date_breaks= "1 months") +
  scale_y_continuous(breaks = seq(0, 700, 100), labels = seq(0, 700, 100)) +
  scale_color_manual(values = c("#FFC125","#00BA38","#F8766D")) +
  theme(plot.subtitle = element_text(vjust = 1),
    plot.caption = element_text(vjust = 1),
    axis.text.x = element_text(vjust = 0.25, angle = 45)
    ) +
  labs(x = NULL, y = NULL, col = NULL, group = NULL, title = "Number of tweets", caption= "  ") +
  theme(plot.title = element_text(hjust = 0.5)) +
  theme(legend.position = c(0.8,0.92), legend.background = element_blank(), legend.key = element_blank())
```



Ho usato il codice indicato sopra sui dati normalizzati usando come baseline il numero di tweets di Dicembre (con *group_by* e *do* di *dyplyr*). 

```r
grid.arrange(timeline_abs, timeline_perc, ncol =  2)
```

<img src="/post/2018-09-10-re-di-twitter-i_files/figure-html/fig.4_timeline-1.png" width="960" />
Sulla sinistra abbiamo i dati assoluti mentre sulla destra i dati in percentuale. Questa normalizzazione ci permette di comparare meglio gli andamenti e i cambiamenti di attività tra i politici.

Salvini twitta molto più di Di Maio e Martina ma __l'attività di tutti e 3 i politici aumenta drasticamente in Febbraio__ di quest'anno, mese di [campagna elettorale](https://it.wikipedia.org/wiki/XVIII_legislatura_della_Repubblica_Italiana)) (con un inizio precoce per Salvini già in Gennaio). Questo picco di attività __crolla velocemente__ e in __Marzo__ già si ritorna a quei livelli di attività pre-elettorali (o anche inferiori nel caso di Di Maio). Un altro __aumento dell'attività__ di __Salvini e Martina__ si osserva __negli ultimi mesi__, sospetto sia in qualche modo collegato alle vicenda dell'Acquarius e della "chiusura dei porti" (fig.3).

## Il successo dei tweets
### Likes per tweet
Ma quanto sono apprezzati i tweets dei 3 politici dai rispettivi followers? Iniziamo vedendo il totale numero di like ottenuti e alcuni indici di tendenza centrale riguardanti likes per ogni tweet.


I numeri sono molto chiari. Con 3200 tweets, __Salvini ha totalizzato più di 4 milioni e mezzo di likes__, una media di quasi 1500 likes a tweet. __Salvini ha ottenuto 5 volte i like di Di Maio e più di dieci volte quelli di Martina (il meno popolare dei tre)__.


Visto che anche in questo caso stiamo avendo a che fare con distribuzioni molto skewed, vale la pena ricorrere a qualche rappresentazione grafica.

```r
twdat %>% 
  ggplot(aes(favoriteCount, col = screenName, fill = screenName)) +
  geom_histogram(position = position_dodge(), bins = 40) +
  scale_color_manual(values = c("#FFC125","#00BA38","#F8766D")) +
  scale_fill_manual(values = c("#FFC125","#00BA38","#F8766D")) +
  labs(col = NULL,
       fill = NULL,
       x = "Likes per 40 tweets",
       y = "Occurances ",
       caption = "fig.4") +
  scale_x_continuous(limits = c(0, 10000))+
  guides(col = FALSE)
```

<img src="/post/2018-09-10-re-di-twitter-i_files/figure-html/fig.4_distribution_fav-1.png" width="960" />

Tutte e tre le distribuzioni sono estremamente skewed verso destra ma anche da questo grafico è possibile cogliere che i tweets di Salvini con alti numeri di likes sono più numerosi rispetto a quelli degli altri 2 politici (barre verdi sono più alte rispetto alle gialle e rosse quando ci spostiamo verso destra,fig.4)

Un altro modo per osservare e comparare i tweets è attraverso il *jitter plot* sottostante.


```r
twdat %>% 
  ggplot(aes(screenName, favoriteCount, col = screenName)) +
  geom_jitter(alpha = 0.2) +
  scale_color_manual(values = c("#FFC125","#00BA38","#F8766D")) +
  labs(x = NULL, y = "Likes", col = "", group = "", title = "Liked tweets", caption = "fig.5") +
  theme(plot.title = element_text(hjust = 0.5),legend.position = "none") 
```

<img src="/post/2018-09-10-re-di-twitter-i_files/figure-html/fig5_jitter_likes-1.png" width="480" />

Nella figura ogni tweet è rappresentato da un punto che è in alto se il tweet ha ricevuto molti likes. Anche da questa rappresentazione si evince che __Salvini è estremamente più popolare tra i suoi followers di Di Maio e Martina__ (fig.5).

### Andamento della popolarità

Come è cambiata la popolarità dei vari politici negli ultimi mesi? Andiamo ad analizzarlo attraverso la visualizzazione di numero di like per tweet (fig.6, sinistra) e totale di like (fig.5) nei mesi di Dicembre 2017 fino a Luglio 2018. Utilizzeremo lo stesso codice impiegato per le fig.1.

<img src="/post/2018-09-10-re-di-twitter-i_files/figure-html/fig.6_plot_timeline_likes-1.png" width="960" />
Sia per __Di Maio__ che per __Salvini__ in numero di __like per tweet è aumentato drasticamente__ a partire __da Marzo del 2018__ con un __picco quest'estaste__ (fig.6 sinistra). Anche __i like  per tweet di Martina sono aumentati__, ma __in misura molto minore__ rispetto a quelli degli altri 2 politici (fig.6 sinistra). Un altra considerazione interessante è che __negli ultimi mesi la popolarità dei tweets di Di Maio e Salvini__ in termini di likes per tweets __non è__ stata tutto sommato __molto differente__ (__2500-4000 likes per tweet__, fig.6 sinistra) e il maggiore numero totale di likes da parte di Salvini è imputabile al sua maggiore presenza sul social media (fig.6 destra).


### I tweets più famosi

Ho deciso di dare una sbirciata ai tweets che hanno riscosso più successo: i 10 tweets di ogni politico con più likes (ordinati in maniera discendente).



```r
# for each screenName takes the 10 tweets with motst likes---
twdat %>% 
  group_by(screenName) %>% 
  do(arrange(.,desc(favoriteCount)) %>% 
       head(10)) %>% 
  ggplot(aes(favoriteCount, reorder(text, favoriteCount), col = screenName)) +
    geom_point() +
    scale_color_manual(values = c("#FFC125","#00BA38","#F8766D")) +
    labs(x = "Number of likes", y = NULL, title = "10 most liked", caption = "fig.7" ) +
    facet_grid(screenName~., scale = "free_y") +
    theme(plot.title = element_text(hjust = 0.5), 
          legend.position="none",

          axis.text.x = element_text(vjust = 0.25, angle = 45)) 
```

<img src="/post/2018-09-10-re-di-twitter-i_files/figure-html/fig.6_10_fav-1.png" width="960" />

Alcuni dei temi più cari ai m5s e Lega emergono nei  tweets più apprezzati:

 * Per Di Maio i vitalizi (3/10) e  il decreto dignità.
 * Per Salvini, le navi di immigrati, i porti e Saviano.

I 10 tweets di Marina con più like sono invece quelli in cui viene presa di mira la politica di m5s e  la Lega. Anche in questo grafico si può notare che i 10 tweets di Salvini hanno ottenuto un numero di like molto maggiore rispetto a quelli di Di Maio e Martina  (i punti sono più spostati verso destra).



## I dispositivi utilizzati 

Per ultimo andiamo a vedere quali sono i dispositivi utilizzati e preferiti dai 3 politici. Un dettaglio forse triviale ma che come ha mostrato [David Robinson](http://varianceexplained.org/r/trump-tweets/) può fornire intuizioni importanti.

```r
# calculate tweets per device and label the one <5% as Other

count_dev <- twdat %>%
  count(statusSource, screenName) %>% # count the number of tweets by screenName
  rename(tw_n = n) %>%
  group_by(screenName) %>% 
  do(mutate(.,tw_perc = tw_n/sum(tw_n)*100)) %>% 
  mutate(perc_lab = round(tw_perc, 1)) # will be labels

         
count_dev$perc_lab[count_dev$perc_lab < 5] <- "" # remove values < 5 to not have a messy plot 

count_dev$statusSource[count_dev$tw_perc < 5]  <- "Other"
```


Creiamo 3 pie charts con percentuali di tweets dai diversi dispositivi.

```r
# Plot percentage of tweets wrote from different devices---

count_dev %>%
  ggplot(aes(x= factor(1), y = tw_perc, fill = statusSource)) +
      geom_col(width = 1) +
      coord_polar(theta = "y") +
      geom_text(aes(label = perc_lab), position = position_stack(vjust = 0.5), size = 3.5) +
      facet_grid(.~screenName) +
      scale_fill_brewer(palette = "Spectral") +
      scale_x_discrete(breaks = NULL, labels = NULL) +
      theme(axis.text.x = element_blank(), axis.text.y = element_blank()) +
      labs(y = NULL, x = NULL, fill = NULL, caption = "fig.8" )
```

<img src="/post/2018-09-10-re-di-twitter-i_files/figure-html/fig.7_pie-1.png" width="960" />
Sono piuttosto chiare le differenze tra i 3 politici:

* Di Maio principalmente utilizza android e twitta post da facebook
* Salvini usa iPhone e computer
* Martina usa quasi esclusivamente il suo iPhone per twittare.

Non vi fanno pensare questi dati? La cosa che a me è balzata agli occhi è che dei 3 è __Salvini__ (o chi per lui) ad utilizzare di  più un Web Client e quindi con molto probabilità  __ad essere seduto alla sua scrivania di fronte al computer per twittare__ (a meno che Di Maio non abbiamo sempre utilizzato Facebook da computer e non da cellulare). Non so voi, ma io quando devo scrivere una email importante, devo leggere un articolo con attenzione o scrivere qualcosa per lavoro, difficilmente uso il mio cellulare: mi siedo alla scrivania e uso il mio PC. È molto probabile che queste differenze nell'uso dei dispositivi sia correlato con altre variabili, ma è senz'altro invitante l'ipotesi che il successo di Salvini su Twitter sia dovuto almeno in una piccola parte dal fatto che consideri molto seriamente la sua attività comunicativa, forse tanto da dedicarne appositamente del tempo al computer. Si tratta ovviamente di speculazioni, ed è altrettanto possibile che semplicemente Salvini passi più tempo alla scrivania rispetto agli altri, che abbia notifiche di Twitter attivate sul desktop, o che ami fare breve pause mentre lavora al computer. 

# Conclusione
I dati non lasciano molti dubbi. 

* Dei tre politici è __Salvini__, con una media di 12 tweets al giorno, di gran lunga __il più attivo su Twitter__ (tab.1, fig.1, fig.3 sinistra). 
* Dei tre politici, è lui quello __con più materiale originale__ (pochissimi retweets, tab.2) e che __twitta in un intervallo di ore più lungo durante giorno__ (fig.1 sinistra).
* Questa maggiore presenza sul social paga (o ne è la sua conseguenza) in termini di apprezzamento da parte dei followers. __Salvini è tra i tre quello con più successo__ in Twitter: con 3200 tweets ha totalizzato __4 milioni e mezzo di likes__, una media di quasi 1500 likes a tweet, __5 volte piu di Di Maio e oltre 10 più di Martina__ (tab.4, fig.5).
* Per tutti e tre i politici c'è stato un __aumento di popolarità negli ultimi mesi di quest'anno__, ma per Salvini e Di Maio in misura estremamente maggiore rispetto a Martina (fig.6).
* __Negli ultimi mesi sia i tweets di Salvini che Di Maio hanno ricevuto ampio apprezzamento__(2500-4000 likes per tweet).
* I temi più apprezzati? Abbiamo dato una sbirciata ai 10 tweets più popolari e per __Salvini__ i temi sono __immigrazione, porti, Saviano__; per __Di Maio sono i vitalizi e il decreto dignità__; __per Martina opposizione alle misure di Lega e Salvini__ (fig.7). 

Seduto alla sua scrivania e con il suo iphone (fig.8), __Salvini ha fatto di *Twitter* il suo regno incontrastato__.






