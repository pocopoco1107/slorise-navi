module ApplicationHelper
  # Render star characters for a given rating (1-5, supports decimals)
  def render_stars(rating)
    return "" unless rating
    full = rating.to_i
    ("★" * full + "☆" * (5 - full)).html_safe
  end
end
