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

  # Rendering is delegated to a per-bucket style object (see #style). The
  # legacy/control style ignores variant:/size: and emits origin/main classes
  # byte-identically; the NDS style honors the variant:/size:/icon_position:
  # API. Both implement css_class(component) + parts(component).
  def css_class
    style.css_class(self)
  end

  def parts
    style.parts(self)
  end

  def icon_content
    render IconComponent.new(icon:) if icon
  end

  def content
    original_content = super
    return original_content if original_content.blank? || icon.blank?

    # Content templates may include leading whitespace, which interferes with
    # the layout when an icon is present. This can be solved in CSS using
    # Flexbox, but doing so for all buttons may have unintended consequences.
    trimmed_content = original_content.lstrip
    trimmed_content = sanitize(trimmed_content) if original_content.html_safe?
    trimmed_content
  end

  private

  # The A/B bucket can only be resolved at render time (helpers/request context
  # are unavailable in #initialize), so the style is selected lazily here — the
  # first #css_class/#parts call happens during render. When the experiment ends
  # this collapses to `LegacyStyle.new` and the NDS style file can be deleted.
  def style
    @style ||= nds_bucket? ? NdsStyle.new : LegacyStyle.new
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
