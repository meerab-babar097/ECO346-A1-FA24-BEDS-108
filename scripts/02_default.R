library(tidyverse)

source("scripts/01_prepare.R")

p <- ggplot(lit_sample, aes(age, literate)) + geom_point()

ggsave("figures/default.svg", plot = p, width = 7, height = 7)