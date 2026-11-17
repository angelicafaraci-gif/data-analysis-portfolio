# Shared plotting helpers, sourced by every analysis.R in this folder.
# Base R only: no extra packages needed for the figures.

PAL  <- c(blue = "#2a78d6", orange = "#eb6834", aqua = "#1baf7a")
INK  <- "#0b0b0b"   # titles and axis labels
INK2 <- "#52514e"   # tick labels and axis lines
GRID <- "#e6e5e1"   # light horizontal grid

# Opens a PNG file in figures/ with a clean, consistent style.
open_png <- function(file, width = 1600, height = 1100, res = 220) {
  dir.create(dirname(file), showWarnings = FALSE, recursive = TRUE)
  png(file, width = width, height = height, res = res, bg = "white")
  par(family = "sans", col.axis = INK2, col.lab = INK, col.main = INK, fg = INK2,
      las = 1, bty = "l", mgp = c(2.8, 0.6, 0), tcl = -0.25,
      font.main = 1, cex.main = 1.05, mar = c(4.4, 4.8, 2.8, 1.2))
}

# Light horizontal grid, drawn before the data so it stays in the background.
hgrid <- function() abline(h = axTicks(2), col = GRID, lwd = 1)

# Boxplot with the raw observations (grey dots) and the group means
# (white diamonds). Group order is the same one boxplot() uses.
box_points <- function(formula, data, col = PAL["blue"], xlab = "", ylab = "",
                       main = "", names = NULL, ylim = NULL, cex.names = 1,
                       las.names = 1) {
  mf <- model.frame(formula, data)
  groups <- split(mf[[1]], mf[-1])
  n <- length(groups)
  col <- rep_len(col, n)
  if (is.null(ylim)) ylim <- range(mf[[1]])
  if (is.null(names)) names <- names(groups)
  plot(NA, xlim = c(0.5, n + 0.5), ylim = ylim, xaxt = "n",
       xlab = xlab, ylab = ylab, main = main)
  hgrid()
  boxplot(groups, add = TRUE, axes = FALSE, outline = FALSE, boxwex = 0.6,
          col = adjustcolor(col, alpha.f = 0.18), border = col, lwd = 1.2,
          medlwd = 2, staplewex = 0.4)
  set.seed(1)
  for (i in seq_len(n)) {
    y <- groups[[i]]
    points(i + runif(length(y), -0.12, 0.12), y, pch = 16, cex = 0.55,
           col = adjustcolor(INK2, alpha.f = 0.6))
  }
  points(seq_len(n), sapply(groups, mean), pch = 23, bg = "white", col = INK, cex = 1.1)
  axis(1, at = seq_len(n), labels = names, cex.axis = cex.names, lwd = 0, lwd.ticks = 1,
       las = las.names)
  invisible(groups)
}

# Mean +/- standard error of y for each level of x, one line per level of
# trace (an interaction plot). Returns the table of means and SEs.
interaction_means <- function(y, x, trace, cols = PAL, xlab = "", ylab = "",
                              main = "", ylim = NULL, legend_pos = "topright") {
  se <- function(v) sd(v) / sqrt(length(v))
  m <- tapply(y, list(x, trace), mean)
  s <- tapply(y, list(x, trace), se)
  k <- ncol(m)
  off <- seq(-0.06, 0.06, length.out = k)   # small dodge so error bars do not overlap
  if (is.null(ylim)) ylim <- range(c(0, m + s, m - s))
  plot(NA, xlim = c(0.7, nrow(m) + 0.3), ylim = ylim, xaxt = "n",
       xlab = xlab, ylab = ylab, main = main)
  hgrid()
  for (j in seq_len(k)) {
    xx <- seq_len(nrow(m)) + off[j]
    ok <- s[, j] > 0   # skip zero-length error bars
    arrows(xx[ok], (m[, j] - s[, j])[ok], xx[ok], (m[, j] + s[, j])[ok], angle = 90,
           code = 3, length = 0.04, col = cols[j], lwd = 1.2)
    lines(xx, m[, j], col = cols[j], lwd = 2)
    points(xx, m[, j], pch = 21, bg = cols[j], col = "white", cex = 1.4, lwd = 1.5)
  }
  axis(1, at = seq_len(nrow(m)), labels = rownames(m), lwd = 0, lwd.ticks = 1)
  legend(legend_pos, legend = colnames(m), col = cols[seq_len(k)], lwd = 2, pch = 21,
         pt.bg = cols[seq_len(k)], bty = "n", text.col = INK)
  invisible(list(mean = m, se = s))
}
