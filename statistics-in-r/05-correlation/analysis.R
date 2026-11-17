# Correlation analysis: two examples
#   1. Conductivity vs ion concentration in 18 lakes
#      (Pearson, Spearman and Kendall coefficients and their tests)
#   2. Heavy metals in marine sediments (correlation matrix for six metals)
#
# Correlation measures how strongly two variables vary together; unlike
# regression it does not treat one variable as depending on the other.
#
# Both datasets are simulated, with the same designs as the course exercises
# (see ../simulate_data.R). They do not describe real places.
#
# How to run: set R's working directory to this folder and run source("analysis.R").
# install.packages("Hmisc")   # once

library(Hmisc)
source("../plot_helpers.R")


# 1. Conductivity vs ion concentration ------------------------------------
lakes <- read.csv("data/lakes_conductivity_ions.csv")

# Pearson's r measures LINEAR association and its test assumes roughly normal
# variables. Spearman's rho and Kendall's tau use ranks: they measure any
# monotonic association (always increasing or always decreasing), and are
# robust to outliers and skewed data. Kendall's tau is usually smaller than
# rho in absolute value because it is computed from concordant pairs.
shapiro.test(lakes$conductivity)
shapiro.test(lakes$ion_concentration)
# P > 0.05 for both: no evidence against normality, so Pearson is appropriate.

cor.test(lakes$conductivity, lakes$ion_concentration, method = "pearson")
cor.test(lakes$conductivity, lakes$ion_concentration, method = "spearman", exact = FALSE)
cor.test(lakes$conductivity, lakes$ion_concentration, method = "kendall", exact = FALSE)
# r = 0.95 (95% CI 0.88 to 0.98), P < 0.001: a very strong positive correlation.
# The rank-based coefficients agree (rho = 0.92, tau = 0.79).

r <- cor(lakes$conductivity, lakes$ion_concentration)
open_png("figures/lakes_conductivity_ions.png")
plot(ion_concentration ~ conductivity, data = lakes, type = "n",
     xlab = expression("Conductivity (" * mu * "S/cm)"), ylab = "Ion concentration (meq/L)",
     main = "Conductivity vs ion concentration in 18 lakes")
hgrid()
points(ion_concentration ~ conductivity, data = lakes, pch = 21, bg = PAL["blue"],
       col = "white", cex = 1.4)
legend("topleft", legend = sprintf("Pearson r = %.2f, P < 0.001", r), bty = "n", text.col = INK)
dev.off()


# 2. Heavy metals in sediments --------------------------------------------
# 36 sediment samples (4 areas x 3 sites x 3 replicates), concentrations in mg/kg.
sediments <- read.csv("data/sediment_metals_mg_kg.csv")
metals <- sediments[, c("Cr", "Cu", "Ni", "Zn", "Pb", "Hg")]
summary(metals)
# Hg is very skewed (from 0.2 to 15.3 mg/kg): Pearson's r would be driven by
# the few highest values, so the rank-based Spearman coefficient is used for
# the matrix, with Pearson as a comparison.

pairs(metals, pch = 16, col = adjustcolor(INK2, 0.6))   # scatterplot matrix

res <- rcorr(as.matrix(metals), type = "spearman")
round(res$r, 2)          # Spearman's rho
p_holm <- res$P
p_holm[upper.tri(p_holm)] <- p.adjust(res$P[upper.tri(res$P)], method = "holm")
p_holm[lower.tri(p_holm)] <- t(p_holm)[lower.tri(p_holm)]
signif(p_holm, 2)        # P-values adjusted for 15 tests (Holm)
round(cor(metals, method = "pearson"), 2)   # Pearson, for comparison

# Cr, Cu, Zn and Hg are strongly correlated with each other (rho 0.63 to 0.84,
# adjusted P < 0.001); Pb is the least correlated metal (only Pb-Cr is
# significant). Caution: the samples are not
# independent (replicates within sites within areas), and Area1 has much
# higher concentrations of most metals, so part of these correlations
# reflects differences among areas. A nested design like this would be
# analysed better with ANOVA or multivariate methods.

dir.create("results", showWarnings = FALSE)
write.csv(round(res$r, 3), "results/spearman_rho.csv")
write.csv(signif(p_holm, 3), "results/spearman_p_holm.csv")

# Correlation heatmap (diverging colours: red negative, grey 0, blue positive)
ramp <- colorRampPalette(c("#e34948", "#f0efec", "#2a78d6"))(201)
rho <- res$r
k <- ncol(rho)
open_png("figures/metals_correlation_matrix.png", width = 1500, height = 1400)
par(mar = c(3.2, 3.6, 3.2, 6))
rho_plot <- rho
diag(rho_plot) <- NA   # the diagonal (each metal with itself) is left blank
image(1:k, 1:k, t(rho_plot[k:1, ]), zlim = c(-1, 1), col = ramp, axes = FALSE,
      xlab = "", ylab = "", main = "Heavy metals in sediments: Spearman's rho")
rect(1:k - 0.5, k:1 - 0.5, 1:k + 0.5, k:1 + 0.5, col = GRID, border = NA)
axis(1, at = 1:k, labels = colnames(rho), lwd = 0)
axis(2, at = 1:k, labels = rev(rownames(rho)), lwd = 0)
abline(h = 0.5 + 0:k, v = 0.5 + 0:k, col = "white", lwd = 2)
for (i in 1:k) for (j in 1:k) {
  if (i != j) {
    star <- ifelse(p_holm[i, j] < 0.05, "*", "")
    text(j, k + 1 - i, paste0(sprintf("%.2f", rho[i, j]), star), cex = 0.85,
         col = ifelse(abs(rho[i, j]) > 0.6, "white", INK))
  }
}
# colour key
par(xpd = TRUE)
yk <- seq(0.5, k + 0.5, length.out = 202)
rect(k + 0.8, yk[-202], k + 1.1, yk[-1], col = ramp, border = NA)
text(k + 1.25, c(0.5, (k + 1) / 2, k + 0.5), c("-1", "0", "+1"), adj = 0, cex = 0.8, col = INK2)
mtext("* Holm-adjusted P < 0.05", side = 1, line = 1.8, cex = 0.75, col = INK2)
dev.off()
