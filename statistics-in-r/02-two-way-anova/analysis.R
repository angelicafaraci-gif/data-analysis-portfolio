# Two-way crossed ANOVA: three examples
#   1. Limpet egg production: season x adult density    (two fixed factors)
#   2. Growth: feed type x sex                            (two fixed factors, significant interaction)
#   3. Species abundance: site x sampling date            (mixed model: fixed x random)
#
# Package GAD is used because it builds the correct F-tests for fixed, random
# and nested factors (Underwood-style designs) and provides Cochran's C test and
# Student-Newman-Keuls (SNK) post-hoc tests. GAD needs a balanced design.
#
# How to run: set R's working directory to this folder and run source("analysis.R").
# install.packages("GAD")   # once

library(GAD)
source("../plot_helpers.R")


# 1. Limpet egg production (Quinn 1988) -----------------------------------
# Effects of season (spring, summer) and adult density (8, 15, 30, 45
# limpets per enclosure) on egg production of Siphonaria diemenensis.
# Both factors are fixed; n = 3 enclosures per combination.
eggs <- read.csv("data/limpet_eggs_season_density.csv", stringsAsFactors = TRUE)
eggs$density <- factor(eggs$density, levels = c(8, 15, 30, 45))   # numeric order, not alphabetical
eggs$season  <- as.fixed(eggs$season)
eggs$density <- as.fixed(eggs$density)

m_eggs <- lm(egg_masses ~ season + density + season:density, data = eggs)
estimates(m_eggs)   # expected mean squares: every term is tested over the residuals
C.test(m_eggs)      # Cochran's C. H0: cell variances are equal
# P > 0.05: variances are homogeneous.

tab_eggs <- gad(m_eggs)
tab_eggs
# Interaction season x density: P > 0.05, the effect of density is the same in both seasons.
# Season and density: both P < 0.001.
# Season has only two levels, so the ANOVA already says spring differs from summer.
# Density has four levels: SNK test to see which densities differ.
snk.test(m_eggs, term = "density", anova.tab = tab_eggs)
# Egg production falls as density increases: 8 > 30 and 45, 15 > 45;
# neighbouring densities do not differ.

open_png("figures/limpet_eggs_interaction.png")
interaction_means(eggs$egg_masses, eggs$density, eggs$season,
                  cols = PAL[c("blue", "orange")], ylim = c(0, 3),
                  xlab = "Adult density (limpets per enclosure)",
                  ylab = "Egg masses per limpet",
                  main = expression("Egg production by season and density (mean" %+-% "SE)"))
dev.off()


# 2. Growth: feed type x sex -----------------------------------------------
# Three feeds (a1, a2, a3) and two sexes, both fixed; n = 5 animals per combination.
growth <- read.csv("data/growth_feed_sex.csv", stringsAsFactors = TRUE)
growth$feed <- as.fixed(growth$feed)
growth$sex  <- as.fixed(growth$sex)

m_growth <- lm(growth_mm_day ~ feed + sex + feed:sex, data = growth)
estimates(m_growth)
C.test(m_growth)
# P < 0.05: variances are NOT homogeneous. Try the usual transformations:
C.test(lm(sqrt(growth_mm_day) ~ feed + sex + feed:sex, data = growth))
C.test(lm(log(growth_mm_day) ~ feed + sex + feed:sex, data = growth))
# Both make the heterogeneity worse. ANOVA is fairly robust when the design is
# balanced, so we analyse the raw data and use a stricter significance level,
# alpha = 0.01, to protect against false positives.

tab_growth <- gad(m_growth)
tab_growth
# Interaction feed x sex: P < 0.01, so the effect of the feed depends on sex.
# Main effects are not interpreted on their own; we compare levels of one
# factor within each level of the other:
snk.test(m_growth, term = "feed:sex", among = "feed", within = "sex", anova.tab = tab_growth)
snk.test(m_growth, term = "feed:sex", among = "sex", within = "feed", anova.tab = tab_growth)
# With alpha = 0.01 only comparisons marked ** or *** count:
# - males:   a3 < a2; a1 does not differ from either
# - females: a3 < a1 and a3 < a2; a1 = a2
# - females grow more than males only with feed a1
# So feed a3 gives the lowest growth in both sexes, and the interaction comes
# from feed a1, which favours females much more than males.

open_png("figures/growth_feed_sex_interaction.png")
interaction_means(growth$growth_mm_day, growth$feed, growth$sex,
                  cols = PAL[c("blue", "orange")], ylim = c(0, 35),
                  xlab = "Feed", ylab = expression("Growth (mm " * day^-1 * ")"),
                  main = expression("Growth by feed and sex (mean" %+-% "SE)"),
                  legend_pos = "bottomleft")
dev.off()


# 3. Species abundance: site (fixed) x date (random) ----------------------
# Two sites (A, B, fixed) sampled on two dates (I, II, random); n = 5 replicates.
abund <- read.csv("data/abundance_site_date.csv", stringsAsFactors = TRUE)
abund$site <- as.fixed(abund$site)
abund$date <- as.random(abund$date)

# Species 1
m_sp1 <- lm(species1 ~ site + date + site:date, data = abund)
estimates(m_sp1)
# In a mixed model, site (fixed) is tested over the site x date interaction,
# not over the residuals: differences between sites are judged against how
# much they change from date to date.
C.test(m_sp1)
tab_sp1 <- gad(m_sp1)
tab_sp1
# No term is significant (all P > 0.05).
# The test for site has only 1 denominator degree of freedom, so it is weak.
# The interaction has P > 0.25, so it can be pooled with the residual
# (Underwood 1997) to get a more powerful test for site:
pooling(m_sp1, term = "site:date", method = "pool", anova.tab = tab_sp1)
# Still not significant: no evidence that species 1 differs between sites or dates.

# Species 2
m_sp2 <- lm(species2 ~ site + date + site:date, data = abund)
C.test(m_sp2)
gad(m_sp2)
# No significant term (date is close, P = 0.07).

open_png("figures/abundance_site_date.png", width = 2200, height = 1100)
par(mfrow = c(1, 2))
par(mfrow = c(1, 2), mar = c(5.4, 4.8, 2.8, 1.2))
cols4 <- PAL[c("blue", "orange", "blue", "orange")]
for (sp in c("species1", "species2")) {
  box_points(as.formula(paste(sp, "~ site + date")), abund, col = cols4,
             names = c("Site A", "Site B", "Site A", "Site B"), ylim = c(0, 100),
             ylab = expression("Individuals " * m^-2),
             main = sub("species", "Species ", sp))
  abline(v = 2.5, col = GRID, lty = 2)
  mtext(c("Date I", "Date II"), side = 1, at = c(1.5, 3.5), line = 2.6, col = INK)
}
dev.off()
