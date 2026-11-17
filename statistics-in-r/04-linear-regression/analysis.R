# Linear regression: three examples
#   1. Calibration line: fluorescence vs concentration
#      (tests on slope and intercept, confidence band, inverse prediction,
#       regression through the origin)
#   2. Body weight vs height (biological data)
#   3. Polynomial regression: Galileo's falling-ball data
#
# How to run: set R's working directory to this folder and run source("analysis.R").
# install.packages("chemCal")   # once, for inverse prediction

library(chemCal)
source("../plot_helpers.R")

# Two-sided t-test of H0: coefficient = value, for a fitted lm model.
test_coef <- function(model, term, value) {
  est <- coef(summary(model))[term, "Estimate"]
  se  <- coef(summary(model))[term, "Std. Error"]
  t   <- (est - value) / se
  p   <- 2 * pt(abs(t), df = df.residual(model), lower.tail = FALSE)
  signif(c(estimate = est, H0_value = value, t = t, P = p), 4)
}

# Fitted line with its 95% confidence band, evaluated on a fine grid.
conf_band <- function(model, xname, from, to, n = 101) {
  grid <- data.frame(seq(from, to, length.out = n))
  names(grid) <- xname
  cbind(grid, predict(model, grid, interval = "confidence", level = 0.95))
}


# 1. Calibration: fluorescence vs concentration ---------------------------
cal <- read.csv("data/calibration_fluorescence.csv")
m_cal <- lm(fluorescence ~ concentration_pg_ml, data = cal)
summary(m_cal)
# Fluorescence = 15.18 + 19.30 * concentration, R^2 = 0.998.
# Slope: P < 0.001, significantly different from 0, so fluorescence does depend
# on concentration. Intercept: P < 0.01, the blank (concentration 0) gives a
# signal clearly above zero.
# A high R^2 alone is not enough: with few points (here 7) a line can have
# R^2 close to 1 and still a slope that is not significant.

confint(m_cal, level = 0.95)

# Tests against a reference value instead of 0 (here 15, as an example):
test_coef(m_cal, "concentration_pg_ml", 15)   # slope differs from 15 (P < 0.001)
test_coef(m_cal, "(Intercept)", 15)           # intercept does not differ from 15 (P > 0.05)

# Residual diagnostics: linearity, normality, constant variance, influential points
open_png("figures/calibration_diagnostics.png", width = 1800, height = 1600)
par(mfrow = c(2, 2), mar = c(4.4, 4.6, 2.6, 1))
plot(m_cal, col = INK2, pch = 16)
dev.off()

# Inverse prediction: concentration of an unknown sample that gives fluorescence 55
inv <- inverse.predict(m_cal, 55)
inv
# Estimated concentration 2.06 pg/mL, 95% confidence interval 1.41 to 2.72.

band <- conf_band(m_cal, "concentration_pg_ml", 0, 12)
open_png("figures/calibration_line.png")
plot(fluorescence ~ concentration_pg_ml, data = cal, type = "n",
     xlab = "Concentration (pg/mL)", ylab = "Fluorescence (photons)",
     main = "Calibration line with 95% confidence band")
hgrid()
polygon(c(band$concentration_pg_ml, rev(band$concentration_pg_ml)), c(band$lwr, rev(band$upr)),
        col = adjustcolor(PAL["blue"], 0.15), border = NA)
lines(band$concentration_pg_ml, band$fit, col = PAL["blue"], lwd = 2)
points(fluorescence ~ concentration_pg_ml, data = cal, pch = 21, bg = INK, col = "white", cex = 1.3)
segments(0, 55, inv$Prediction, 55, col = PAL["orange"], lty = 2, lwd = 1.5)
segments(inv$Prediction, 55, inv$Prediction, par("usr")[3], col = PAL["orange"], lty = 2, lwd = 1.5)
arrows(inv$`Confidence Limits`[1], 20, inv$`Confidence Limits`[2], 20, angle = 90, code = 3,
       length = 0.04, col = PAL["orange"], lwd = 1.5)
text(inv$Prediction + 0.3, 33, sprintf("unknown sample: Y = 55\nX = %.2f pg/mL (95%% CI %.2f-%.2f)",
     inv$Prediction, inv$`Confidence Limits`[1], inv$`Confidence Limits`[2]),
     adj = 0, cex = 0.8, col = INK)
dev.off()

# Regression through the origin (intercept fixed at 0)
m_cal0 <- lm(fluorescence ~ 0 + concentration_pg_ml, data = cal)
summary(m_cal0)
# R^2 here is computed around 0, not around the mean, so it cannot be compared
# with the R^2 of the model with intercept. In this case forcing the line
# through 0 is not justified: the intercept of the full model is
# significantly different from 0 (P < 0.01).
anova(m_cal0, m_cal)   # the model with intercept fits significantly better


# 2. Body weight vs height ------------------------------------------------
hw <- read.csv("data/height_weight.csv")
m_hw <- lm(weight_kg ~ height_cm, data = hw)
summary(m_hw)
# Weight = -73.35 + 0.80 * height, R^2 = 0.80, P < 0.01:
# on average +0.8 kg for every extra cm.
confint(m_hw)   # slope: 0.34 to 1.25 kg per cm

open_png("figures/height_weight_diagnostics.png", width = 1800, height = 1600)
par(mfrow = c(2, 2), mar = c(4.4, 4.6, 2.6, 1))
plot(m_hw, col = INK2, pch = 16)
dev.off()

band <- conf_band(m_hw, "height_cm", min(hw$height_cm), max(hw$height_cm))
open_png("figures/height_weight.png")
plot(weight_kg ~ height_cm, data = hw, type = "n", ylim = c(45, 80),
     xlab = "Height (cm)", ylab = "Weight (kg)", main = "Weight vs height with 95% confidence band")
hgrid()
polygon(c(band$height_cm, rev(band$height_cm)), c(band$lwr, rev(band$upr)),
        col = adjustcolor(PAL["blue"], 0.15), border = NA)
lines(band$height_cm, band$fit, col = PAL["blue"], lwd = 2)
points(weight_kg ~ height_cm, data = hw, pch = 21, bg = INK, col = "white", cex = 1.3)
dev.off()


# 3. Polynomial regression: Galileo's data --------------------------------
# Release height of a ball on an inclined ramp and horizontal distance travelled
# (Galileo, 1608). The relationship is curved, so we compare a straight line
# with a quadratic model.
galileo <- data.frame(height   = c(100, 200, 300, 450, 600, 800, 1000),
                      distance = c(253, 337, 395, 451, 495, 534, 574))
m_lin  <- lm(distance ~ height, data = galileo)
m_quad <- lm(distance ~ height + I(height^2), data = galileo)
summary(m_quad)    # all three coefficients significant, R^2 = 0.99
anova(m_lin, m_quad)
# The quadratic term improves the fit significantly (P < 0.01).

band <- conf_band(m_quad, "height", 100, 1000)
lin  <- conf_band(m_lin,  "height", 100, 1000)
open_png("figures/galileo_quadratic.png")
plot(distance ~ height, data = galileo, type = "n", ylim = c(200, 650),
     xlab = "Release height", ylab = "Horizontal distance",
     main = "Galileo's data: straight line vs quadratic model")
hgrid()
polygon(c(band$height, rev(band$height)), c(band$lwr, rev(band$upr)),
        col = adjustcolor(PAL["blue"], 0.15), border = NA)
lines(lin$height, lin$fit, col = INK2, lwd = 1.5, lty = 2)
lines(band$height, band$fit, col = PAL["blue"], lwd = 2)
points(distance ~ height, data = galileo, pch = 21, bg = INK, col = "white", cex = 1.3)
legend("bottomright", legend = c("Quadratic model (95% band)", "Straight line"),
       col = c(PAL["blue"], INK2), lwd = c(2, 1.5), lty = c(1, 2), bty = "n", text.col = INK)
dev.off()
