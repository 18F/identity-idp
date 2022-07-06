class AsyncButtonComponent < BaseComponent
  attr_reader :unhandled_error_message, :poll_interval, :alert_target, :tag_options

  def initialize(
    unhandled_error_message: t('idv.failure.exceptions.internal_error'),
    poll_interval: nil,
    alert_target: nil,
    **tag_options
  )
    @unhandled_error_message = unhandled_error_message
    @poll_interval = poll_interval
    @alert_target = alert_target
    @tag_options = tag_options
  end

  def call
    content_tag(
      'lg-async-button',
      render(SpinnerButtonComponent.new(**tag_options).with_content(content)),
      'poll-interval': poll_interval,
      'unhandled-error-message': unhandled_error_message,
      'alert-target': alert_target,
    )
  end
end
