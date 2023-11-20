class IconListComponent < BaseComponent
  renders_many :items, ->(**kwargs, &block) do
    IconListItemComponent.new(icon:, color:, **kwargs, &block)
  end

  attr_reader :icon, :size, :color, :tag_options

  def initialize(icon: nil, size: 'md', color: nil, **tag_options)
    @icon = icon
    @size = size
    @color = color
    @tag_options = tag_options
  end

  def css_class
    classes = ['usa-icon-list', *tag_options[:class]]
    classes << ["usa-icon-list--size-#{size}"] if size
    classes
  end

  class IconListItemComponent < BaseComponent
    attr_reader :icon, :color, :tag_options

    def initialize(icon:, color:, **tag_options)
      @icon = icon
      @color = color
      @tag_options = tag_options
    end

    def icon_css_class
      classes = ['usa-icon-list__icon']
      classes << "text-#{color}" if color
      classes
    end
  end
end
