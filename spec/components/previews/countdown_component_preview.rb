class CountdownComponentPreview < BaseComponentPreview
  # @!group Kitchen Sink
  def default
    render(CountdownComponent.new(expiration: Time.zone.now + 1.5.minutes))
  end
  # @!endgroup

  # @param expiration datetime-local
  # @param update_interval number
  # @param start_immediately toggle
  def playground(
    expiration: Time.zone.now + 1.5.minutes,
    update_interval: 1,
    start_immediately: true
  )
    render(
      CountdownComponent.new(
        expiration: expiration,
        update_interval: update_interval.seconds,
        start_immediately: start_immediately,
      ),
    )
  end
end
