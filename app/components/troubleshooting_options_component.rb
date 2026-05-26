# frozen_string_literal: true

class TroubleshootingOptionsComponent < BaseComponent
  renders_one :header, 'TroubleshootingOptionsHeadingComponent'
  renders_many :options, BlockLinkComponent

  attr_reader :tag_options

  def initialize(options: [], **tag_options)
    @options_from_constructor = options
    @tag_options = tag_options.dup
  end

  def all_options
    @all_options ||= @options_from_constructor.map(&method(:render)) + options
  end

  def render?
    all_options.present?
  end

  def css_class
    [
      'troubleshooting-options',
      *tag_options[:class],
    ].select(&:present?)
  end

  class TroubleshootingOptionsHeadingComponent < BaseComponent
    attr_reader :heading_level

    def initialize(heading_level: :h2)
      @heading_level = heading_level
    end

    def call
      content_tag(heading_level, content, class: 'troubleshooting-options__heading')
    end
  end
end
