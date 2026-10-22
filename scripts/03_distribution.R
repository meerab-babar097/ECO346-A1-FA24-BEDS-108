library(tidyverse)
library(scales)

source("scripts/01_prepare.R")

# ---- 1. Numbers to report ----
n_students <- nrow(students)
w_med <- w_quantile(students$ed_total, students$hhweight, 0.5)
u_med <- median(students$ed_total)
p10   <- w_quantile(students$ed_total, students$hhweight, 0.1)
p90   <- w_quantile(students$ed_total, students$hhweight, 0.9)
ratio <- round(p90 / p10, 2)

# ---- 2. Keep Rs 100 to Rs 1,000,000 (log10 from 2 to 6) ----
students <- students %>% mutate(logx = log10(ed_total))
in_range <- students %>% filter(logx >= 2, logx <= 6)
n_excl   <- n_students - nrow(in_range)

# ---- 3. Weighted histogram: 40 bins, each 0.1 wide in log10 units ----
hist_df <- in_range %>%
  mutate(bin = pmin(floor(round((logx - 2) / 0.1, 8)) + 1, 40)) %>%
  group_by(bin) %>%
  summarise(w = sum(hhweight), .groups = "drop") %>%
  right_join(tibble(bin = 1:40), by = "bin") %>%
  arrange(bin) %>%
  mutate(w = replace_na(w, 0),
         mid = 2 + (bin - 1) * 0.1 + 0.05,
         density = w / sum(w) / 0.1)

ytop <- max(hist_df$density) * 1.05

# ---- 4. Figure ----
p <- ggplot(hist_df, aes(mid, density)) +
  geom_col(width = 0.1, fill = "grey60", colour = "white") +
  geom_vline(xintercept = log10(w_med), linetype = "dashed") +
  geom_vline(xintercept = log10(p90),   linetype = "dashed") +
  annotate("text", x = log10(w_med), y = ytop, hjust = 1.05,
           label = paste0("Median: Rs ", comma(w_med))) +
  annotate("text", x = log10(p90), y = ytop, hjust = -0.05,
           label = paste0("90th percentile: Rs ", comma(p90))) +
  scale_x_continuous(breaks = 2:6,
                     labels = paste0("Rs ", comma(10^(2:6)))) +
  coord_cartesian(xlim = c(2, 6), ylim = c(0, max(hist_df$density) * 1.12)) +
  labs(title = paste0("Half of rural Punjab's students cost households Rs ",
                      comma(w_med), " a year or less; the top tenth over Rs ",
                      comma(p90)),
       x = "Annual education spending per student (log scale)",
       y = "Density per log10 unit",
       caption = paste0("Source: PSLM 2019-20 person and household files. ",
                        "Sample: students (ed_total > 0), Punjab rural, n = ",
                        comma(n_students), "; ", n_excl,
                        " students outside Rs 100 to Rs 1,000,000 excluded. ",
                        "Weighted by hhweight.")) +
  theme_minimal() +
  theme(plot.title   = element_text(face = "bold", size = 11),
        plot.caption = element_text(hjust = 0, size = 8))

ggsave("figures/distribution.svg", plot = p, width = 9, height = 5)
print(p)

# ---- 5. Report ----
cat("Students:", n_students, "\n")
cat("Weighted median:", round(w_med), "| Unweighted median:", round(u_med), "\n")
cat("Weighted P10:", round(p10), "| P90:", round(p90), "| Ratio:", sprintf("%.2f", ratio), "\n")
cat("Excluded:", n_excl, "\n")
cat("Bins:", nrow(hist_df), "| Density check (should be 1):", sum(hist_df$density) * 0.1, "\n")