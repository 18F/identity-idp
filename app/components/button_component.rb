# frozen_string_literal: true

class ButtonComponent < BaseComponent
  # NDS-bucket variant/size API (gsa-staging parity), emitted on standard
  # USWDS `.usa-button` selectors so Path 4's nds overlay styles them and the
  # look can backport to USWDS. primary = base `.usa-button` (no modifier);
  # destructive reuses the existing `--danger` modifier (bucket-differentiated
  # by CSS: legacy renders today's danger, nds overlay renders NDS destructive).
  VARIANTS = {
    primary: nil,
    secondary: 'usa-button--secondary',
    tertiary: 'usa-button--tertiary',
    quaternary: 'usa-button--quaternary',
    ghost: 'usa-button--ghost',
    destructive: 'usa-button--danger',
  }.freeze

  SIZES = {
    lg: 'usa-button--lg',
    md: 'usa-button--md',
    sm: 'usa-button--sm',
  }.freeze

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

  # In the NDS bucket, honor the variant:/size: API. In the legacy/control
  # bucket, ignore variant:/size: and honor the existing boolean API so output
  # is byte-identical to origin/main.
  def css_class
    nds_bucket? ? nds_css_class : legacy_css_class
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

  # Legacy bucket keeps origin/main ordering ([icon_content, content]). NDS
  # bucket honors icon_position and icon-only rendering (gsa-staging parity).
  def parts
    return [icon_content, content] unless nds_bucket?
    return [icon_content] if icon_only?

    icon_position == :right ? [content, icon_content] : [icon_content, content]
  end

  private

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

  def legacy_css_class
    classes = ['usa-button', *tag_options[:class]]
    classes << 'usa-button--big' if big
    classes << 'usa-button--wide' if wide
    classes << 'usa-button--full-width' if full_width
    classes << 'usa-button--outline' if outline
    classes << 'usa-button--unstyled' if unstyled
    classes << 'usa-button--danger' if danger
    classes
  end

  def nds_css_class
    classes = [
      'usa-button',
      VARIANTS.fetch(variant),
      SIZES.fetch(size),
      *tag_options[:class],
    ].compact

    if icon
      classes << (icon_only? ? 'usa-button--icon-only' : icon_position_class)
    end

    classes
  end

  def icon_only?
    icon.present? && content.blank?
  end

  def icon_position_class
    icon_position == :right ? 'usa-button--icon-right' : 'usa-button--icon-left'
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
