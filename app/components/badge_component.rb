# frozen_string_literal: true

class BadgeComponent < BaseComponent
  ICONS = %i[
    unphishable
    success
  ].to_set.freeze

  attr_reader :icon, :tag_options

  def initialize(icon:, **tag_options)
    raise ArgumentError, "invalid icon #{icon}, expected one of #{ICONS}" if !ICONS.include?(icon)
    @icon = icon
    @tag_options = tag_options
  end
end
