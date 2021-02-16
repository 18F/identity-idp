module SessionTimeoutWarningHelper
  def session_timeout_frequency
    (AppConfig.env.session_check_frequency || 150).to_i
  end

  def session_timeout_start
    (AppConfig.env.session_check_delay || 30).to_i
  end

  def session_timeout_warning
    (AppConfig.env.session_timeout_warning_seconds || 30).to_i
  end

  def timeout_refresh_path
    UriService.add_params(
      request.original_fullpath,
      timeout: true,
    )&.html_safe # rubocop:disable Rails/OutputSafety
  end

  def time_left_in_session
    distance_of_time_in_words(
      warning,
      0,
      two_words_connector: " #{I18n.t('datetime.dotiw.two_words_connector')} ",
    )
  end

  def session_modal
    if user_fully_authenticated?
      FullySignedInModalPresenter.new(time_left_in_session)
    else
      PartiallySignedInModalPresenter.new(time_left_in_session)
    end
  end
end

ActionView::Base.send :include, SessionTimeoutWarningHelper
