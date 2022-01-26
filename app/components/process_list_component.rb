class ProcessListComponent < BaseComponent
  renders_many :items, 'ProcessListItemComponent'

  attr_reader :heading_level, :big, :connected, :tag_options

  def initialize(heading_level: :h2, big: false, connected: false, **tag_options)
    @heading_level = heading_level
    @big = big
    @connected = connected
    @tag_options = tag_options
  end

  def css_class
    classes = ['usa-process-list', *tag_options[:class]]
    classes << 'usa-process-list--big' if big
    classes << 'usa-process-list--connected' if connected
    classes
  end

  class ProcessListItemComponent < BaseComponent
    attr_reader :heading, :heading_level

    def initialize(heading:, heading_level: :h2)
      @heading_level = heading_level
      @heading = heading
    end
  end
end
