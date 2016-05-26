module SessionTimeoutWarningHelper
  def frequency
    Rails.application.config.session_check_frequency
  end

  def start
    Rails.application.config.session_check_delay
  end

  def warning
    Rails.application.config.session_timeout_warning_seconds
  end

  def auto_session_timeout_js
    nonced_javascript_tag do
      render partial: 'session_timeout/ping',
             formats: [:js],
             locals: {
               warning: warning,
               start: start,
               frequency: frequency
             }
    end
  end

  def time_left_in_session
    distance_of_time_in_words(warning)
  end
end

ActionView::Base.send :include, SessionTimeoutWarningHelper
