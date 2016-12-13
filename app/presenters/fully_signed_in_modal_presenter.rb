class FullySignedInModalPresenter < SessionTimeoutWarningModalPresenter
  def message
    t('notices.timeout_warning.signed_in.message_html',
      time_left_in_session: content_tag(:span, time_left_in_session, id: 'countdown'))
  end

  def continue
    t('notices.timeout_warning.signed_in.continue')
  end

  def sign_out
    t('notices.timeout_warning.signed_in.sign_out')
  end
end
