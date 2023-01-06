class CountdownAlertComponent < BaseComponent
  attr_reader :show_at_remaining, :alert_options, :countdown_options, :redirect_url, :tag_options

  def initialize(show_at_remaining: nil, alert_options: {}, countdown_options: {}, redirect_url: nil, **tag_options)
    @show_at_remaining = show_at_remaining
    @alert_options = alert_options
    @countdown_options = countdown_options
    @tag_options = tag_options
    @redirect_url = redirect_url
  end

  def call
    content_tag(
      :'lg-countdown-alert',
      content,
      **tag_options,
      class: css_class,
      'show-at-remaining': show_at_remaining&.in_milliseconds,
      # is there a redirect url? what happens if there's none? -> check if it is here || '' 
      'redirect-url': redirect_url
    )
  end

  def content
    AlertComponent.new(
      **alert_options,
      type: :info,
      class: alert_css_class,
    ).with_content(alert_content).render_in(view_context)
  end

  private

  def alert_content
    t(
      'components.countdown_alert.time_remaining_html',
      countdown_html: CountdownComponent.new(**countdown_options).render_in(view_context),
    )
  end

  def css_class
    classes = [*tag_options[:class]]
    classes << 'display-none' if show_at_remaining.present?
    classes
  end

  def alert_css_class
    [*alert_options[:class], 'usa-alert--info-time']
  end
end
