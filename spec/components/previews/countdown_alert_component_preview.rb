class CountdownAlertComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render(
      CountdownAlertComponent.new(countdown_options: { expiration: Time.zone.now + 1.5.minutes }),
    )
  end

  def shown_at_time_remaining
    render(
      CountdownAlertComponent.new(
        countdown_options: { expiration: Time.zone.now + 1.5.minutes },
        show_at_remaining: 1.minute,
      ),
    )
  end
  # @!endgroup

  # @param expiration datetime-local
  # @param show_at_remaining_seconds number
  def workbench(
    expiration: Time.zone.now + 1.5.minutes,
    show_at_remaining_seconds: nil
  )
    render(
      CountdownAlertComponent.new(
        show_at_remaining: show_at_remaining_seconds&.seconds,
        countdown_options: { expiration: expiration },
      ),
    )
  end
end
