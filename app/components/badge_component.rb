# frozen_string_literal: true

class BadgeComponent < BaseComponent
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

  # The badge's rendering can only be resolved at render time (helpers are
  # unavailable in #initialize). Callers always instantiate BadgeComponent;
  # when the render resolves to the NDS bucket we delegate to
  # NDSBadgeComponent, which renders its own markup. The guard excludes
  # NDSBadgeComponent itself so it renders its own markup instead of recursing.
  def before_render
    super
    @render_as_nds = nds_bucket? && !is_a?(NDSBadgeComponent)
  end

  private

  def render_as_nds?
    @render_as_nds
  end

  def legacy_render?
    !nds_bucket? && !is_a?(NDSBadgeComponent)
  end

  def nds_delegate
    nds_variant_class.new(icon:, variant:, on_background:, **tag_options)
  end

  def nds_variant_class
    NDSBadgeComponent
  end

  # ViewComponent delegates #helpers to the current view context, where
  # nds_layout? is exposed as a controller helper_method. Guard for view
  # contexts without that helper (e.g. mailers). When the bucket can't be
  # resolved because there is no auth context (background jobs, isolated
  # component renders — Devise::MissingWarden), default to the legacy bucket:
  # legacy is the conservative default and rendering must never crash.
  def nds_bucket?
    return false unless helpers.respond_to?(:nds_layout?)

    helpers.nds_layout?
  rescue Devise::MissingWarden
    false
  end
end
