local wezterm = require 'wezterm'

return {
  xcursor_theme = "Bibata-Modern-Classic",
  xcursor_size = 24,

  window_frame = {
    font = wezterm.font('Noto Sans', { weight = "DemiBold" }),
    font_size = 12.5,
    inactive_titlebar_bg = '242424',
    active_titlebar_bg = '353535',
  },
  hide_tab_bar_if_only_one_tab = true,
  use_resize_increments = true,

  enable_wayland = true;

  default_cursor_style = "BlinkingBar",
  cursor_blink_ease_in = "EaseIn",
  cursor_blink_ease_out = "EaseOut",
  cursor_blink_rate = 600,

  font = wezterm.font_with_fallback{
    {
      family = 'Fira Code Retina',
      harfbuzz_features = {'calt', 'cv01', 'cv02', 'cv06', 'cv14', 'ss01', 'ss03', 'ss04', 'ss05', 'ss07', 'zero'},
    },
    'Symbols Nerd Font Mono',
  },
  font_size = 14,

  colors = {
    background = "1f1f1f",
    foreground = "eeeeee",

    cursor_bg = "aaaaaa",
    cursor_fg = "dddddd",

    ansi = {"241f31", "c01c28", "2ec27e", "f5c211", "1e78e4", "9841bb", "0ab9dc", "c0bfbc"},
    brights = {"5e5c64", "ed333b", "57e389", "f8e45c", "51a1ff", "c061cb", "4fd2fd", "f6f5f4"},
  },

  keys = {
    {
      key = 'Backspace',
      mods = 'CTRL',
      action = wezterm.action.SendKey {
        key = 'h', mods = 'CTRL'
      },
    }
  },
}
