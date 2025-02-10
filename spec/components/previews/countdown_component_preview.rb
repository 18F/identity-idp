class CountdownComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render(CountdownComponent.new(expiration: Time.zone.now + 1.5.minutes))
  end
  # @!endgroup

  # @param expiration datetime-local
  # @param update_interval number
  # @param start_immediately toggle
  def workbench(
    expiration: Time.zone.now + 1.5.minutes,
    update_interval: 1,
    start_immediately: true
  )
    render(
      CountdownComponent.new(
        expiration:,
        update_interval: update_interval.seconds,
        start_immediately:,
      ),
    )
  end
end
