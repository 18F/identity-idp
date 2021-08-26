module SessionTimeoutWarningHelper
  def session_timeout_frequency
    IdentityConfig.store.session_check_frequency
  end

  def session_timeout_start
    IdentityConfig.store.session_check_delay
  end

  def session_timeout_warning
    IdentityConfig.store.session_timeout_warning_seconds
  end

  def timeout_refresh_path
    UriService.add_params(
      request.original_fullpath,
      timeout: true,
    )&.html_safe # rubocop:disable Rails/OutputSafety
  end

  def time_left_in_session
    distance_of_time_in_words(session_timeout_warning, 0)
  end

  def session_modal
    if user_fully_authenticated?
      FullySignedInModalPresenter.new(time_left_in_session)
    else
      PartiallySignedInModalPresenter.new(time_left_in_session)
    end
  end
end
