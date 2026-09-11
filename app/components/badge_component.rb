# frozen_string_literal: true

class BadgeComponent < BaseComponent
  include NDSBucketResolvable

  attr_reader :icon, :variant, :on_background, :tag_options

  # Legacy rendering requires a known icon. NDS rendering makes the icon
  # optional and selects styling from variant:, so the icon inclusion check
  # only runs when this badge renders its legacy markup.
  validates_inclusion_of :icon,
                         in: %i[lock check_circle warning info],
                         if: :legacy_render?

  # variant: and on_background: are part of the shared badge API. Legacy
  # rendering ignores both; on_background: is accepted for API compatibility
  # but never emits anything.
  def initialize(icon: nil, variant: :primary, on_background: :light, **tag_options)
    @icon = icon&.to_sym
    @variant = variant.to_sym
    @on_background = on_background&.to_sym
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

  private

  def legacy_render?
    !nds_bucket? && !is_a?(NDSBadgeComponent)
  end

  def nds_delegate
    nds_variant_class.new(icon:, variant:, on_background:, **tag_options)
  end

  # The NDS variant excluded from the render-time flip (see
  # NDSBucketResolvable) so it renders its own markup instead of recursing.
  def nds_variant_class
    NDSBadgeComponent
  end
end
