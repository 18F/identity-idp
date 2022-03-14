class FullySignedInModalPresenter
  include ActionView::Helpers::TranslationHelper

  def initialize(view_context:, expiration:)
    @view_context = view_context
    @expiration = expiration
  end

  def message
    t(
      'notices.timeout_warning.signed_in.message_html',
      time_left_in_session: view_context.render(
        CountdownComponent.new(expiration: expiration, start_immediately: false),
      ),
    )
  end

  def sr_message
    t(
      'notices.timeout_warning.signed_in.sr_message_html',
      time_left_in_session: view_context.render(
        CountdownComponent.new(
          expiration: expiration,
          update_interval: 30.seconds,
          start_immediately: false,
        ),
      ),
    )
  end

  def continue
    t('notices.timeout_warning.signed_in.continue')
  end

  def sign_out
    t('notices.timeout_warning.signed_in.sign_out')
  end

  private

  attr_reader :expiration, :view_context
end
