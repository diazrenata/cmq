library(drake)
library(ggplot2)

many_vects <- list()

for(i in 1:1000) {
  many_vects[[i]] <- seq(i, i + 10, by = 1)
}

a_plan <- drake_plan(
  means = target(mean(a_vect),
                 transform = map(a_vect = !!many_vects),
                 hpc = T),
  means_mean = target(mean(means),
                      transform = combine(means))
)

## Set up the cache and config
db <- DBI::dbConnect(RSQLite::SQLite(), here::here("analysis", "drake", "drake-cache.sqlite"))
cache <- storr::storr_dbi("datatable", "keystable", db)

## Run the pipeline
nodename <- Sys.info()["nodename"]
if(grepl("ufhpc", nodename)) {
  print("I know I am on the HiPerGator!")
  library(clustermq)
  options(clustermq.scheduler = "slurm", clustermq.template = "slurm_clustermq.tmpl")
  ## Run the pipeline parallelized for HiPerGator
  make(a_plan,
       force = TRUE,
       cache = cache,
       cache_log_file = here::here("analysis", "drake", "cache_log.txt"),
       verbose = 2,
       parallelism = "clustermq",
       jobs = 50,
       caching = "main", memory_strategy = "autoclean") # Important for DBI caches!
} else {
  library(clustermq)
  options(clustermq.scheduler = "multicore")
  # Run the pipeline on multiple local cores
  system.time(make(a_plan, cache = cache, cache_log_file = here::here("analysis", "drake", "cache_log.txt"), parallelism = "clustermq", jobs = 2))
}

DBI::dbDisconnect(db)
rm(cache)
print("Completed OK")
