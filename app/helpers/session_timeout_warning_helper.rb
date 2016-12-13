module SessionTimeoutWarningHelper
  def frequency
    (Figaro.env.session_check_frequency || 150).to_i
  end

  def start
    (Figaro.env.session_check_delay || 30).to_i
  end

  def warning
    (Figaro.env.session_timeout_warning_seconds || 30).to_i
  end

  def timeout_refresh_url
    URI(request.original_url).tap do |url|
      query = Rack::Utils.parse_nested_query(url.query).with_indifferent_access
      url.query = query.merge(timeout: true).to_query
    end.to_s
  end

  def auto_session_timeout_js
    nonced_javascript_tag do
      render partial: 'session_timeout/ping',
             formats: [:js],
             locals: {
               warning: warning,
               start: start,
               frequency: frequency,
               modal: modal
             }
    end
  end

  def auto_session_expired_js
    session_timeout_in = Devise.timeout_in
    nonced_javascript_tag do
      render(
        partial: 'session_timeout/expire_session',
        formats: [:js],
        locals: { session_timeout_in: session_timeout_in }
      )
    end
  end

  def time_left_in_session
    distance_of_time_in_words(warning)
  end

  def modal
    if user_fully_authenticated?
      FullySignedInModal.new(time_left_in_session)
    else
      PartiallySignedInModal.new(time_left_in_session)
    end
  end

  FullySignedInModal = Struct.new(:time_left_in_session) do
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::TranslationHelper

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

  class PartiallySignedInModal < FullySignedInModal
    def message
      t('notices.timeout_warning.partially_signed_in.message_html',
        time_left_in_session: content_tag(:span, time_left_in_session, id: 'countdown'))
    end

    def continue
      t('notices.timeout_warning.partially_signed_in.continue')
    end

    def sign_out
      t('notices.timeout_warning.partially_signed_in.sign_out')
    end
  end
end

ActionView::Base.send :include, SessionTimeoutWarningHelper
