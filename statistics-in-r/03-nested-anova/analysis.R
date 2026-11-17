# Nested (hierarchical) ANOVA: three examples
#   1. Limpets inside and outside a marine protected area   (site nested in protection)
#   2. Benthic species richness and wave exposure           (area nested in exposure)
#   3. Coral rubble at control and impacted reefs           (site nested in impact, crossed with depth)
#
# In a nested design the levels of the nested factor (sites, areas) are
# different in each level of the factor above: site "A" in the protected zone
# is not the same place as site "A" outside it. The nested factor is usually
# random; it is the replication unit used to test the factor above it.
#
# All three datasets are simulated, with the same designs as the course
# exercises (see ../simulate_data.R). They do not describe real places.
#
# How to run: set R's working directory to this folder and run source("analysis.R").

library(GAD)
source("../plot_helpers.R")


# 1. Limpets and protection -----------------------------------------------
# Protection: fixed (P = protected, NP = not protected).
# Site: random, 2 sites nested in each protection level; n = 6 samples per site.
limpets <- read.csv("data/limpets_protection.csv", stringsAsFactors = TRUE)
limpets$protection <- as.fixed(limpets$protection)
limpets$site       <- as.random(limpets$site)

m_lim <- lm(limpets ~ protection + site %in% protection, data = limpets)
estimates(m_lim)   # protection is tested over site(protection), not over the residuals
C.test(m_lim)      # P > 0.05: variances are homogeneous
tab_lim <- gad(m_lim)
tab_lim
# Site(protection), i.e. variability among sites within the same protection
# level (a nested term, not an interaction): P > 0.05.
# Protection: P > 0.05, no evidence that limpet density differs between
# protected and unprotected shores. With only 2 sites per level the test for
# protection has 1 and 2 degrees of freedom, so it has very little power.

open_png("figures/limpets_protection.png")
box_points(limpets ~ site + protection, limpets,
           col = PAL[c("blue", "blue", "orange", "orange")],
           names = c("Site A", "Site B", "Site A", "Site B"),
           ylab = "Limpets per sample", main = "Limpets by site and protection level")
abline(v = 2.5, col = GRID, lty = 2)
mtext(c("Not protected", "Protected"), side = 1, at = c(1.5, 3.5), line = 2.6, col = INK)
dev.off()


# 2. Species richness and wave exposure -----------------------------------
# Exposure: fixed, 3 levels (sheltered, intermediate, exposed).
# Area: random, 4 areas nested in each exposure level; n = 3 replicates per area.
rich <- read.csv("data/richness_exposure.csv")
rich$exposure <- factor(rich$exposure, levels = c("sheltered", "intermediate", "exposed"))
rich$exposure <- as.fixed(rich$exposure)
rich$area     <- as.random(rich$area)

m_rich <- lm(richness_S ~ exposure + area %in% exposure, data = rich)
estimates(m_rich)
C.test(m_rich)     # P > 0.05: variances are homogeneous
tab_rich <- gad(m_rich)
tab_rich
# Area(exposure): P < 0.05, richness varies among areas with the same exposure.
# Exposure: P < 0.05. Note that exposure is tested over area(exposure) with
# only 9 degrees of freedom: the replicates inside an area are not independent
# evidence about exposure, the areas are.
# Exposure is fixed with 3 levels, so an SNK test shows which levels differ:
snk.test(m_rich, term = "exposure", anova.tab = tab_rich)
# Intermediate exposure has higher richness than sheltered and exposed areas,
# which do not differ from each other.

open_png("figures/richness_exposure.png", width = 2000, height = 1100)
par(mar = c(5.4, 4.8, 2.8, 1.2))
box_points(richness_S ~ area + exposure, rich,
           col = rep(PAL[c("blue", "orange", "aqua")], each = 4),
           names = rep(c("a", "b", "c", "d"), 3), ylim = c(0, 60),
           ylab = "Species richness (S)", main = "Species richness by area and wave exposure")
abline(v = c(4.5, 8.5), col = GRID, lty = 2)
mtext(c("Sheltered", "Intermediate", "Exposed"), side = 1, at = c(2.5, 6.5, 10.5), line = 2.6, col = INK)
dev.off()


# 3. Coral rubble at control and impacted reefs ---------------------------
# Impact: fixed (Control, Impact).
# Depth: fixed (6, 12, 18 m), crossed with impact.
# Site: random, 4 sites nested in each impact level.
# n = 5 replicates per site and depth. Response: coral rubble cover (%).
rubble <- read.csv("data/coral_rubble_control_impact.csv")
rubble$depth  <- factor(rubble$depth, levels = c("6 m", "12 m", "18 m"))
rubble$impact <- as.fixed(rubble$impact)
rubble$depth  <- as.fixed(rubble$depth)
rubble$site   <- as.random(rubble$site)

f_rubble <- ~ impact + depth + impact:depth + site %in% impact + depth:(site %in% impact)
m_rub <- lm(update(f_rubble, coral_rubble_pct ~ .), data = rubble)
estimates(m_rub)   # check that every term has a valid denominator
C.test(m_rub)
# P < 0.001: strongly heterogeneous variances (rubble is almost absent at the
# control sites). A strong transformation, power 0.2 (fifth root):
rubble$rubble_t <- rubble$coral_rubble_pct^0.2
m_rub_t <- lm(update(f_rubble, rubble_t ~ .), data = rubble)
C.test(m_rub_t)    # P > 0.05: homogeneous after the transformation

tab_rub <- gad(m_rub_t)
tab_rub
# Impact x depth: P < 0.05, so the difference between control and impact
# depends on depth, and the main effects are not interpreted on their own.
snk.test(m_rub_t, term = "impact:depth", among = "impact", within = "depth", anova.tab = tab_rub)
snk.test(m_rub_t, term = "impact:depth", among = "depth", within = "impact", anova.tab = tab_rub)
# Rubble cover is higher at impacted than at control reefs at every depth
# (P < 0.001). At impacted reefs it is lower at 18 m than at 6 and 12 m,
# while control reefs have very little rubble at any depth: this is the interaction.

open_png("figures/coral_rubble_control_impact.png")
interaction_means(rubble$coral_rubble_pct, rubble$depth, rubble$impact,
                  cols = PAL[c("blue", "orange")], ylim = c(0, 40),
                  xlab = "Depth", ylab = "Coral rubble cover (%)",
                  main = expression("Coral rubble, control vs impact (mean" %+-% "SE)"))
dev.off()
