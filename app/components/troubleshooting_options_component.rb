class TroubleshootingOptionsComponent < BaseComponent
  renders_one :header, 'TroubleshootingOptionsHeadingComponent'
  renders_many :options, BlockLinkComponent

  attr_reader :tag_options

  def initialize(**tag_options)
    @tag_options = tag_options.dup
    @new_features = @tag_options.delete(:new_features)
  end

  def render?
    options?
  end

  def new_features?
    @new_features
  end

  def css_class
    [
      'troubleshooting-options',
      new_features? && 'troubleshooting-options__no-bar',
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
