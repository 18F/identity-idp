# frozen_string_literal: true

class ClickObserverComponent < BaseComponent
  attr_reader :event_name, :tag_options, :payload

  def initialize(event_name:, payload: {}, **tag_options)
    @event_name = event_name
    @payload = payload
    @tag_options = tag_options
  end

  def call
    content_tag(
      :'lg-click-observer', content, 'event-name': @event_name,
                                     data: { payload: payload }, **tag_options
    )
  end
end
