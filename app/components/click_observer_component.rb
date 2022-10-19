class ClickObserverComponent < BaseComponent
  attr_reader :event_name, :tag_options

  def initialize(event_name:, **tag_options)
    @event_name = event_name
    @tag_options = tag_options
  end

  def call
    content_tag(:'lg-click-observer', content, 'event-name': @event_name, **tag_options)
  end
end
