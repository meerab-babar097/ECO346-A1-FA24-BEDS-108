library(tidyverse)
library(scales)

source("scripts/01_prepare.R")

# ---- 1. Band table: weighted literacy by 5-year age band and sex ----
band_tbl <- lit_sample %>%
  mutate(band    = floor(age / 5) * 5,          # 10, 15, ..., 60
         mid     = band + 2,                    # 12, 17, ..., 62
         sex_lab = if_else(sex == 2, "Women", "Men")) %>%
  group_by(band, mid, sex_lab) %>%
  summarise(n = n(),
            rate = 100 * w_mean(literate, hhweight),
            .groups = "drop") %>%
  mutate(thin = n < 30)

# ---- 2. Band with the largest gap between men and women ----
gap <- band_tbl %>%
  select(band, mid, sex_lab, rate) %>%
  pivot_wider(names_from = sex_lab, values_from = rate) %>%
  mutate(gap = Men - Women)
big <- gap %>% slice_max(abs(gap), n = 1)
big_label <- paste0(big$band, "-", big$band + 4)

# ---- 3. Figure ----
ends <- band_tbl %>% filter(mid == max(mid))

p <- ggplot(band_tbl, aes(mid, rate, colour = sex_lab, group = sex_lab)) +
  geom_line(linewidth = 0.8) +
  geom_point(data = filter(band_tbl, !thin), size = 2.6) +
  geom_point(data = filter(band_tbl, thin), shape = 21,
             fill = "white", size = 2.6, stroke = 1) +
  geom_text(data = ends, aes(label = sex_lab), hjust = -0.25,
            fontface = "bold", show.legend = FALSE) +
  annotate("segment", x = big$mid, xend = big$mid,
           y = big$Women, yend = big$Men,
           colour = "grey30", linetype = "dotted") +
  annotate("label", x = big$mid + 1, y = (big$Women + big$Men) / 2,
           hjust = 0, size = 3.5, fill = "white", label.size = 0,
           label = paste0("Largest gap, ages ", big_label, ":\n",
                          sprintf("%.1f", abs(big$gap)), " percentage points")) +
  scale_colour_manual(values = c(Women = "#C0392B", Men = "#2C6FAC")) +
  scale_x_continuous(breaks = seq(12, 62, 5)) +
  scale_y_continuous(labels = function(x) paste0(x, "%")) +
  coord_cartesian(xlim = c(10, 68), ylim = c(0, 100)) +
  labs(title = paste0("In rural Punjab the literacy gap between men and women is widest at ages ",
                      big_label, ": ", sprintf("%.1f", big$Men), "% of men vs ",
                      sprintf("%.1f", big$Women), "% of women"),
       x = "Age (midpoint of 5-year band)",
       y = "Weighted literacy rate",
       caption = str_wrap(paste0(
         "Source: PSLM 2019-20 person and household files. Sample: persons aged 10-64 ",
         "with non-missing literacy, Punjab rural, n = ", comma(nrow(lit_sample)),
         ". Weighted by hhweight. Hollow markers mark bands with fewer than 30 ",
         "observations for that sex."), width = 110)) +
  theme_minimal() +
  theme(legend.position = "none",
        plot.title   = element_text(face = "bold", size = 11),
        plot.caption = element_text(hjust = 0, size = 8))

ggsave("figures/literacy_by_age.svg", plot = p, width = 9, height = 5.5)
print(p)

# ---- 4. Save the band table (for README and for the Python check in Q5) ----
write_csv(band_tbl, "figures/band_table_R.csv")

wide <- band_tbl %>%
  mutate(label = paste0(band, "-", band + 4)) %>%
  select(label, sex_lab, n, rate) %>%
  pivot_wider(names_from = sex_lab, values_from = c(n, rate))

md <- c("| Band | Women (n) | Women literacy % | Men (n) | Men literacy % |",
        "|---|---|---|---|---|",
        sprintf("| %s | %d | %.1f | %d | %.1f |",
                wide$label, wide$n_Women, wide$rate_Women,
                wide$n_Men, wide$rate_Men))
writeLines(md, "figures/band_table_R.md")

# ---- 5. Report ----
get_rate <- function(b, s) sprintf("%.1f", band_tbl$rate[band_tbl$band == b & band_tbl$sex_lab == s])
cat("Women 15-19:", get_rate(15, "Women"), "| Men 15-19:", get_rate(15, "Men"), "\n")
cat("Women 55-59:", get_rate(55, "Women"), "| Men 55-59:", get_rate(55, "Men"), "\n")
cat("Largest gap band:", big_label, "| gap:", sprintf("%.1f", abs(big$gap)), "points\n")
cat("Thin cells:", sum(band_tbl$thin), "\n")
print(as.data.frame(band_tbl))