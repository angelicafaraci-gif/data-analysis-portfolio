# One-way ANOVA: three examples
#   1. Iron in air across three zones            (fixed factor, unbalanced)
#   2. Algal turf cover at 12 reef sites         (random factor, transformed data; simulated data)
#   3. Algal growth under three types of light   (fixed factor + Tukey post-hoc test)
#
# How to run: set R's working directory to this folder
# (R GUI on Windows: File > Change dir...) and run source("analysis.R").
# Figures are saved in figures/.

source("../plot_helpers.R")
se <- function(x) sd(x) / sqrt(length(x))


# 1. Iron in air ----------------------------------------------------------
# Question: does the mean iron concentration differ among three zones?
# Factor: zone (fixed, 3 levels: A, B, C; n = 6, 4, 5).
iron <- read.csv("data/iron_in_air.csv", stringsAsFactors = TRUE)
str(iron)

tapply(iron$iron_ug_Nm3, iron$zone, mean)
tapply(iron$iron_ug_Nm3, iron$zone, se)

# Assumption: homogeneity of variances (Bartlett's test, used here because
# the design is unbalanced). H0: the group variances are equal.
bartlett.test(iron_ug_Nm3 ~ zone, data = iron)
# P > 0.05: no evidence against equal variances, so the ANOVA can be run.

m_iron <- lm(iron_ug_Nm3 ~ zone, data = iron)
anova(m_iron)
# P > 0.05: we do not reject H0. The data give no evidence that mean iron
# concentration differs among the three zones.

open_png("figures/iron_by_zone.png")
box_points(iron_ug_Nm3 ~ zone, iron, col = PAL["blue"], xlab = "Zone",
           ylab = expression("Iron (" * mu * "g N" * m^-3 * ")"),
           main = "Iron in air by zone")
dev.off()


# 2. Algal turf cover at 12 reef sites ------------------------------------
# Question: does algal turf cover vary among sites?
# Factor: site (random, 12 sites sampled at random; n = 10 replicates per site).
# Simulated data with the same design as the course exercise (see ../simulate_data.R).
turf <- read.csv("data/algal_turf_sites.csv", stringsAsFactors = TRUE)
str(turf)

bartlett.test(algal_turf_pct ~ site, data = turf)
# P < 0.05: variances are not homogeneous. Square-root transformation
# (common for percentage cover and counts) and test again:
turf$sqrt_turf <- sqrt(turf$algal_turf_pct)
bartlett.test(sqrt_turf ~ site, data = turf)
# P > 0.05 after the transformation: the ANOVA is run on sqrt-transformed data.

m_turf <- lm(sqrt_turf ~ site, data = turf)
tab_turf <- anova(m_turf)
tab_turf
# P < 0.001: cover differs among sites. The P-value is the probability of an
# F at least this large if H0 were true; it is not the probability that the
# result is "due to chance".
#
# Site is a random factor, so post-hoc comparisons between particular sites
# are not meaningful. Instead we estimate how much of the variation is due
# to differences among sites (variance component):
n_per_site <- 10
var_site  <- (tab_turf["site", "Mean Sq"] - tab_turf["Residuals", "Mean Sq"]) / n_per_site
var_resid <- tab_turf["Residuals", "Mean Sq"]
round(100 * var_site / (var_site + var_resid), 1)   # % of variance among sites

open_png("figures/algal_turf_raw_vs_sqrt.png", width = 2200, height = 1100)
par(mfrow = c(1, 2), mar = c(5.2, 4.8, 2.8, 1))
box_points(algal_turf_pct ~ site, turf, xlab = "", ylab = "Algal turf cover (%)",
           main = "Raw data", cex.names = 0.75, las.names = 2)
mtext("Site", side = 1, line = 3.9, col = INK)
box_points(sqrt_turf ~ site, turf, col = PAL["aqua"], xlab = "",
           ylab = "sqrt(cover)", main = "Square-root transformed", cex.names = 0.75,
           las.names = 2)
mtext("Site", side = 1, line = 3.9, col = INK)
dev.off()


# 3. Algal growth under three types of light ------------------------------
# Question: does algal growth depend on the type of lamp?
# Factor: light (fixed, 3 lamps chosen on purpose; n = 4, 3, 3).
algae <- read.csv("data/algal_growth_light.csv", stringsAsFactors = TRUE)

bartlett.test(growth_pct ~ light, data = algae)
# P > 0.05: variances are homogeneous.

m_algae <- aov(growth_pct ~ light, data = algae)
summary(m_algae)
# P < 0.05: mean growth differs among the three lamps.

# The factor is fixed, so a post-hoc test tells us which lamps differ.
# Tukey's HSD compares every pair while keeping the family-wise error at 5%.
TukeyHSD(m_algae)
# B vs A and C vs B: adjusted P < 0.05, so lamp B gives higher growth than A and C.
# C vs A: adjusted P > 0.05, no difference.

means <- tapply(algae$growth_pct, algae$light, mean)
errs  <- tapply(algae$growth_pct, algae$light, se)
open_png("figures/algal_growth_by_light.png")
par(mar = c(5.6, 4.8, 2.8, 1.2))
x <- barplot(means, ylim = c(0, 0.4), col = adjustcolor(PAL["blue"], 0.85),
             border = NA, space = 1, axes = FALSE, xlab = "Lamp", ylab = "Growth (%)",
             main = expression("Algal growth by type of light (mean" %+-% "SE)"))
hgrid()
barplot(means, add = TRUE, col = adjustcolor(PAL["blue"], 0.85), border = NA,
        space = 1, axes = FALSE, names.arg = rep("", 3))
axis(2)
arrows(x, means - errs, x, means + errs, angle = 90, code = 3, length = 0.05, col = INK, lwd = 1.2)
text(x, means + errs + 0.02, labels = c("a", "b", "a"), col = INK)   # Tukey groups
mtext(expression("Lamps sharing a letter do not differ (Tukey HSD, " * alpha * " = 0.05)"),
      side = 1, line = 4.4, cex = 0.75, col = INK2)
dev.off()
