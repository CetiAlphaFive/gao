## hex_gao.R
## Hex sticker for gao package
##
## Palette: "Wheat Field Under Open Sky"
##   Deep sky:  #2E5A82  (hex fill)
##   Cloud:     #F5F0E6  (border, text)

pacman::p_load(ggplot2, hexSticker, showtext, sysfonts)

## --- Palette ---
col.deep.sky <- "#2E5A82"
col.cloud    <- "#F5F0E6"

## --- Font setup ---
font_add_google("EB Garamond", "ebgaramond")
showtext_auto()

## --- Subplot: three letters arranged diagonally, each upright ---
## Diagonal runs from lower-left to upper-right
letters.df <- data.frame(
  label = c("G", "A", "O"),
  x     = c(-.75, -.75, -.75),
  y     = c(.75, 0, -.75)
)

## Small text to the right of each big letter
small.df <- data.frame(
  label = c("overnment", "ccountability", "ffice"),
  x     = c(-0.45, -0.45, -0.45),
  y     = c(.70, -.07, -.8)
)

p <- ggplot(letters.df, aes(x = x, y = y, label = label)) +
  geom_text(family = "ebgaramond", fontface = "bold",
            size = 35, colour = col.cloud, vjust = 0.5, hjust = 0.5) +
  geom_text(data = small.df, aes(x = x, y = y, label = label),
            family = "ebgaramond", fontface = "plain",
            size = 13, colour = col.cloud, vjust = 1, hjust = 0) +
  coord_cartesian(xlim = c(-1, 1), ylim = c(-1, 1)) +
  theme_void() +
  theme(
    plot.background  = element_rect(fill = "transparent", colour = NA),
    panel.background = element_rect(fill = "transparent", colour = NA)
  )

## --- Create hex sticker ---
out.path <- "/run/media/jack/storage/Dropbox/gao/man/figures/hex_gao.png"

sticker(
  subplot    = p,
  package    = "",
  p_size     = 0,
  s_x        = 1.0,
  s_y        = 1.0,
  s_width    = 1.4,
  s_height   = 1.2,
  h_fill     = col.deep.sky,
  h_color    = col.cloud,
  h_size     = 1.5,
  filename   = out.path,
  dpi        = 300
)

cat("Saved:", out.path, "\n")
