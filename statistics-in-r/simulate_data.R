# Creates the simulated datasets used in some of the analyses.
#
# The course exercises for these examples used real field data that are not
# mine to publish. To keep the analyses reproducible, I generated new data
# with the same sampling designs (factors, levels and replicates) but with
# invented parameters. The numbers do not describe any real place.
#
# Run from this folder: source("simulate_data.R")

set.seed(2026)
write_data <- function(df, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  write.csv(df, path, row.names = FALSE)
}


# 01 - Algal turf cover (%) at 12 random reef sites, 10 replicates per site.
# Site means vary on the square-root scale, so on the raw scale the variance
# grows with the mean (a typical pattern for cover data).
sites <- sprintf("S%02d", 1:12)
site_mean <- pmax(rnorm(12, mean = 5, sd = 1.8), 0.5)          # sqrt scale
turf <- expand.grid(replicate = 1:10, site = sites)
turf$algal_turf_pct <- round(pmin(pmax(rnorm(nrow(turf), site_mean[turf$site], 1.4), 0)^2, 100), 2)
write_data(turf[, c("site", "replicate", "algal_turf_pct")], "01-one-way-anova/data/algal_turf_sites.csv")


# 03 - Limpets per sample inside (P) and outside (NP) a marine protected area,
# 2 sites per protection level, 6 samples per site (negative binomial counts).
lim <- expand.grid(sample = 1:6, site = c("A", "B"), protection = c("NP", "P"))
mu <- c(NP.A = 6, NP.B = 8, P.A = 13, P.B = 9)[paste(lim$protection, lim$site, sep = ".")]
lim$limpets <- rnbinom(nrow(lim), mu = mu, size = 4)
write_data(lim[, c("protection", "site", "sample", "limpets")], "03-nested-anova/data/limpets_protection.csv")


# 03 - Species richness under three levels of wave exposure,
# 4 areas nested in each level, 3 replicates per area (Poisson counts).
rich <- expand.grid(replicate = 1:3, area = c("a", "b", "c", "d"),
                    exposure = c("sheltered", "intermediate", "exposed"))
exp_mean  <- c(sheltered = 24, intermediate = 38, exposed = 22)
area_mean <- exp_mean[rich$exposure] * exp(rnorm(12, 0, 0.12))[as.integer(interaction(rich$area, rich$exposure))]
rich$richness_S <- rpois(nrow(rich), area_mean)
write_data(rich[, c("exposure", "area", "replicate", "richness_S")], "03-nested-anova/data/richness_exposure.csv")


# 03 - Coral rubble cover (%) at control and impacted reefs, 3 depths,
# 4 sites nested in each impact level, 5 replicates.
# Rubble is rare at control sites and common at impacted ones, less so at 18 m.
rub <- expand.grid(replicate = 1:5, site = c("A", "B", "C", "D"),
                   depth = c("6 m", "12 m", "18 m"), impact = c("Control", "Impact"))
site_eff  <- exp(rnorm(8, 0, 0.5))[as.integer(interaction(rub$site, rub$impact))]
depth_eff <- c("6 m" = 15, "12 m" = 20, "18 m" = 3)[as.character(rub$depth)]
base <- ifelse(rub$impact == "Impact", depth_eff * site_eff, 1)
present <- rbinom(nrow(rub), 1, ifelse(rub$impact == "Impact", 0.9, 0.3))
rub$coral_rubble_pct <- round(present * pmin(base * exp(rnorm(nrow(rub), 0, 0.6)), 100), 2)
write_data(rub[, c("impact", "depth", "site", "replicate", "coral_rubble_pct")],
           "03-nested-anova/data/coral_rubble_control_impact.csv")


# 05 - Conductivity (uS/cm) and ion concentration (meq/L) in 18 lakes.
lakes <- data.frame(lake = sprintf("L%02d", 1:18), conductivity = round(runif(18, 18, 46)))
lakes$ion_concentration <- round(0.021 * lakes$conductivity + rnorm(18, 0, 0.04), 3)
write_data(lakes, "05-correlation/data/lakes_conductivity_ions.csv")


# 05 - Heavy metals (mg/kg) in 36 sediment samples: 4 areas x 3 sites x 3
# replicates. Area 1 is contaminated, so most metals are higher there; Hg is
# very skewed. A shared sample effect makes the metals co-vary.
sed <- expand.grid(replicate = 1:3, site = c("A", "B", "C"), area = paste0("Area", 1:4))
baseline <- c(Cr = 80, Cu = 30, Ni = 42, Zn = 80, Pb = 12, Hg = 0.6)
area1    <- c(Cr = 1.4, Cu = 2.6, Ni = 1.2, Zn = 3.2, Pb = 1.5, Hg = 20)
noise_sd <- c(Cr = 0.15, Cu = 0.2, Ni = 0.1, Zn = 0.2, Pb = 0.5, Hg = 0.6)
shared <- rnorm(nrow(sed), 0, 0.15)
for (m in names(baseline)) {
  mult <- ifelse(sed$area == "Area1", area1[m], 1)
  sed[[m]] <- round(baseline[m] * mult * exp(shared + rnorm(nrow(sed), 0, noise_sd[m])), 2)
}
write_data(sed, "05-correlation/data/sediment_metals_mg_kg.csv")

cat("Simulated datasets written.\n")
