# frozen_string_literal: true

module ADS
  class PageShellComponent < BaseComponent
    MODIFIERS = {
      align: %w[mobile-start start stretch],
      density: %w[fullscreen mobile-compact spacious],
      surface: %w[overlay],
      width: %w[form wide],
    }.freeze

    renders_one :chrome
    renders_one :footer
    renders_one :body

    attr_reader :page_class, :density, :align, :surface, :width, :hide_chrome, :hide_footer,
                :main_tag, :transition
    MODIFIERS.each do |name, values|
      validates name, inclusion: { in: values }, allow_nil: true
    end

    def initialize(
      page_class: nil,
      width: nil,
      density: nil,
      align: nil,
      surface: nil,
      main_tag: :main,
      transition: true,
      hide_chrome: false,
      hide_footer: false
    )
      @page_class = page_class.to_s.squish
      @width = normalize(width)
      @density = normalize(density)
      @align = normalize(align)
      @surface = normalize(surface)
      @main_tag = main_tag
      @transition = transition
      @hide_chrome = hide_chrome
      @hide_footer = hide_footer
    end

    def body_class
      [
        'site',
        'ads-auth-page',
        page_class.presence,
        *modifier_classes,
      ].compact.join(' ')
    end

    def main_options
      {
        class: 'ads-auth-page__main',
        id: ('main-content' if main_tag.to_sym == :main),
      }
    end

    private

    def normalize(value)
      value.to_s.dasherize.presence
    end

    def modifier_classes
      MODIFIERS.keys.filter_map do |name|
        value = public_send(name)
        "ads-auth-page--#{name}-#{value}" if value
      end
    end
  end
end
