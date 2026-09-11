# frozen_string_literal: true

module NDS
  # Vertical stack primitive (net-new NDS layout component; renders only in the
  # nds layout). Renders the .stack/.flow/.form/.actions/.links layout classes
  # with optional --gap-N and --align-* modifiers.
  #
  #   NDS::StackComponent(kind: :form) do        # 32 - between groups
  #     NDS::StackComponent(align: :stretch) do  # 12 - fields / title+copy
  #     NDS::StackComponent(kind: :actions) do   # 12 - buttons
  class StackComponent < BaseComponent
    CLASS_BY_KIND = {
      actions: 'actions',
      flow: 'flow',
      form: 'form',
      links: 'links',
      stack: 'stack',
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

    def base_class
      CLASS_BY_KIND.fetch(kind)
    end

    def css_class
      [base_class, gap_class, align_class, html_options[:class]].compact.join(' ')
    end

    def gap_class
      return if gap.blank?

      "#{base_class}--gap-#{gap}"
    end

    def align_class
      return if align.blank?

      "#{base_class}--align-#{align}"
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
