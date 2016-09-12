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
