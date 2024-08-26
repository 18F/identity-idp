# frozen_string_literal: true

class BadgeComponent < BaseComponent
  attr_reader :icon, :tag_options

  validates_inclusion_of :icon, in: %i[
    lock
    check_circle
    warning
    info
  ]

  def initialize(icon:, **tag_options)
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
