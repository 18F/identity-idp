class PartiallySignedInModalPresenter
  include ActionView::Helpers::TranslationHelper

  def initialize(expiration)
    @expiration = expiration
  end

  def message(view_context)
    t(
      'notices.timeout_warning.partially_signed_in.message_html',
      time_left_in_session: view_context.render_to_string(
        CountdownComponent.new(expiration: expiration, start_immediately: false),
      ),
    )
  end

  def sr_message(view_context)
    t(
      'notices.timeout_warning.partially_signed_in.sr_message_html',
      time_left_in_session: view_context.render_to_string(
        CountdownComponent.new(
          expiration: expiration,
          update_interval: 30.seconds,
          start_immediately: false,
        ),
      ),
    )
  end

  def continue
    t('notices.timeout_warning.partially_signed_in.continue')
  end

  def sign_out
    t('notices.timeout_warning.partially_signed_in.sign_out')
  end

  private

  attr_reader :expiration
end
