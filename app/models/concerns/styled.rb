# The person-colour contract Wes's CSS relies on: --c (fill), --c-rgb (for rgb(var(--c-rgb) / a)),
# --c-ink (text on the fill). Shared by Person and the Family pseudo-person.
module Styled
  extend ActiveSupport::Concern

  # Relative luminance above the midpoint: dark text reads better.
  def self.light?(hex)
    r, g, b = hex.to_s.delete("#").scan(/../).map { |h| h.to_i(16) / 255.0 }
    return false unless b
    lin = ->(c) { c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4 }
    0.2126 * lin.(r) + 0.7152 * lin.(g) + 0.0722 * lin.(b) > 0.5
  end

  def rgb
    color.delete("#").scan(/../).map { |h| h.to_i(16) }.join(" ")
  end

  def style
    "--c:#{color};--c-rgb:#{rgb};--c-ink:#{ink}"
  end
end
