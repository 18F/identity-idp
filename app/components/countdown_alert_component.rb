class CountdownAlertComponent < AlertComponent
  attr_reader :show_at_remaining, :alert_options, :countdown_options

  def initialize(show_at_remaining: nil, countdown_options: nil, **alert_options)
    @show_at_remaining = show_at_remaining
    @alert_options = alert_options
    @countdown_options = countdown_options

    super(type: :info, **alert_options, class: alert_css_class)
  end

  def call
    content_tag(
      :'lg-countdown-alert',
      super,
      'show-at-remaining': show_at_remaining&.in_milliseconds,
    )
  end

  def content
    t(
      'components.countdown_alert.time_remaining_html',
      countdown: CountdownComponent.new(**countdown_options).render_in(self),
    )
  end

  private

  def alert_css_class
    [*alert_options[:class], 'usa-alert--info-time']
  end
end
