# frozen_string_literal: true

class BadgeComponent < BaseComponent
  ICONS = %i[
    lock
    check_circle
    warning
    info
  ].to_set.freeze

  attr_reader :icon, :tag_options

  def initialize(icon:, **tag_options)
    raise ArgumentError, "invalid icon #{icon}, expected one of #{ICONS}" if !ICONS.include?(icon)
    @icon = icon
    @tag_options = tag_options
  end

  def color_token
    case icon
    when :check_circle, :lock
      'success'
    when :warning
      'warning'
    else
      'info'
    end
  end

  def border_css_class
    "border-#{color_token}"
  end

  def icon_css_class
    "text-#{color_token}"
  end
end
