class TroubleshootingOptionsComponent < BaseComponent
  renders_one :header, 'TroubleshootingOptionsHeadingComponent'
  renders_many :options, BlockLinkComponent

  attr_reader :tag_options

  def initialize(**tag_options)
    @tag_options = tag_options.dup
  end

  def render?
    options?
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
