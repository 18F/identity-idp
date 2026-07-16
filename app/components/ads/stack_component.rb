# frozen_string_literal: true

module ADS
  class StackComponent < BaseComponent
    CLASS_BY_KIND = {
      actions: 'ads-actions',
      flow: 'ads-flow',
      form: 'ads-form',
      links: 'ads-links',
      stack: 'ads-stack',
    }.freeze

    attr_reader :tag_name, :kind, :gap, :align, :html_options

    def initialize(tag: :div, kind: :stack, gap: nil, align: nil, **html_options)
      @tag_name = tag
      @kind = kind.to_sym
      @gap = normalize_gap(gap)
      @align = normalize(align)
      @html_options = html_options
    end

    def call
      content_tag(tag_name, content, html_options.except(:class).merge(class: css_class))
    end

    private

    def css_class
      [
        CLASS_BY_KIND.fetch(kind),
        gap_class,
        align_class,
        html_options[:class],
      ].compact.join(' ')
    end

    def gap_class
      return if gap.blank?

      "#{CLASS_BY_KIND.fetch(kind)}--gap-#{gap}"
    end

    def align_class
      return if align.blank?

      "#{CLASS_BY_KIND.fetch(kind)}--align-#{align}"
    end

    def normalize(value)
      value.to_s.dasherize.presence
    end

    def normalize_gap(value)
      return if value.nil?

      Integer(value)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
