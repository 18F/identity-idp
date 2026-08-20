# frozen_string_literal: true

class ButtonComponent < BaseComponent
  attr_reader :url,
              :method,
              :icon,
              :icon_position,
              :size,
              :variant,
              :big,
              :wide,
              :full_width,
              :outline,
              :unstyled,
              :danger,
              :tag_options

  def initialize(
    url: nil,
    method: nil,
    icon: nil,
    icon_position: :left,
    size: :lg,
    variant: :primary,
    big: false,
    wide: false,
    full_width: false,
    outline: false,
    unstyled: false,
    danger: false,
    **tag_options
  )
    @url = url
    @method = method
    @icon = icon
    @icon_position = icon_position.to_sym
    @size = size.to_sym
    @variant = variant.to_sym
    @big = big
    @wide = wide
    @full_width = full_width
    @outline = outline
    @unstyled = unstyled
    @danger = danger
    @tag_options = tag_options
  end

  # Legacy/control bucket behavior. Byte-identical to origin/main: variant:/size:
  # are ignored and the boolean API is honored. NdsButtonComponent overrides
  # css_class/parts for the NDS bucket.
  def css_class
    classes = ['usa-button', *tag_options[:class]]
    classes << 'usa-button--big' if big
    classes << 'usa-button--wide' if wide
    classes << 'usa-button--full-width' if full_width
    classes << 'usa-button--outline' if outline
    classes << 'usa-button--unstyled' if unstyled
    classes << 'usa-button--danger' if danger
    classes
  end

  def parts
    [icon_content, content]
  end

  def icon_content
    render IconComponent.new(icon:) if icon
  end

  def content
    original_content = super
    return original_content if original_content.blank? || icon.blank?

    trimmed_content = original_content.lstrip
    trimmed_content = sanitize(trimmed_content) if original_content.html_safe?
    trimmed_content
  end

  # The A/B bucket can only be resolved at render time (helpers are unavailable
  # in #initialize). Callers always instantiate ButtonComponent; when the render
  # resolves to the NDS bucket we delegate to NdsButtonComponent, which renders
  # itself with the variant/size API. The subclass sets this false so it renders
  # its own (NDS) markup instead of recursing.
  def before_render
    super
    @render_as_nds = nds_bucket? && instance_of?(ButtonComponent)
  end

  private

  def render_as_nds?
    @render_as_nds
  end

  def nds_delegate
    NdsButtonComponent.new(
      url:, method:, icon:, icon_position:, size:, variant:,
      big:, wide:, full_width:, outline:, unstyled:, danger:,
      **tag_options
    )
  end

  # ViewComponent delegates #helpers to the current view context, where
  # nds_layout? is exposed as a controller helper_method. Guard for view
  # contexts without that helper (e.g. mailers). When the A/B bucket can't be
  # resolved because there is no auth context (background jobs, isolated
  # component renders — Devise::MissingWarden), default to the legacy bucket:
  # legacy is the conservative default and rendering must never crash.
  def nds_bucket?
    return false unless helpers.respond_to?(:nds_layout?)

    helpers.nds_layout?
  rescue Devise::MissingWarden
    false
  end

  def action
    @action ||= begin
      if url
        if method && method != :get
          ->(**tag_options, &block) { button_to(url, method:, **tag_options, &block) }
        else
          ->(**tag_options, &block) { link_to(url, **tag_options, &block) }
        end
      else
        ->(**tag_options, &block) { button_tag(**tag_options, &block) }
      end
    end
  end
end
