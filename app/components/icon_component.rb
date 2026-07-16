# frozen_string_literal: true

class IconComponent < BaseComponent
  ASSET_ROOT = Rails.root.join('app/assets/images').freeze
  ICON_ROOT = ASSET_ROOT.join('ads/icons').freeze

  REGISTRY = ICON_ROOT.children.sort.filter_map do |dir|
    next unless dir.directory?

    variants = dir.glob('*.svg').sort.to_h do |file|
      [Integer(file.basename('.svg').to_s), file.relative_path_from(ASSET_ROOT).to_s]
    end.freeze

    [dir.basename.to_s.to_sym, variants] if variants.any?
  end.to_h.freeze

  attr_reader :icon, :label, :size, :tag_options

  validates :icon, inclusion: { in: REGISTRY.keys }
  validate :size_is_supported

  def initialize(icon:, size: 24, label: nil, **tag_options)
    @icon = icon&.to_sym
    @size = size.to_i
    @label = label.presence
    @tag_options = tag_options
  end

  def call
    tag.svg(**svg_options) { helpers.raw(self.class.markup_for(asset_path)) }
  end

  def self.markup_for(asset_path)
    (@markup_cache ||= {})[asset_path] ||= begin
      content = ASSET_ROOT.join(asset_path).read
      content[/<svg\b[^>]*>(.*)<\/svg>/im, 1] || raise(ArgumentError, "Invalid SVG: #{asset_path}")
    end
  end

  private

  def svg_options
    options = tag_options.merge(
      class: helpers.class_names('ads-icon', tag_options[:class]),
      width: size,
      height: size,
      viewBox: "0 0 #{size} #{size}",
      fill: 'none',
      focusable: false,
    )

    if label
      options.merge(role: 'img', 'aria-label': label, 'aria-hidden': nil)
    else
      options.merge('aria-hidden': true, role: nil, 'aria-label': nil)
    end
  end

  def size_is_supported
    return if asset_path

    errors.add(
      :size,
      :unsupported,
      message: "`size` #{size} is not supported for #{icon || 'this icon'}",
    )
  end

  def asset_path
    REGISTRY.dig(icon, size)
  end
end
