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

  def expires_at
    session[:session_expires_at]&.to_datetime || Time.zone.now - 1
  end

  def timeout_refresh_path
    UriService.add_params(
      request.original_fullpath,
      timeout: true,
    )&.html_safe # rubocop:disable Rails/OutputSafety
  end

  def session_modal
    if user_fully_authenticated?
      FullySignedInModalPresenter.new(view_context: self, expiration: expires_at)
    else
      PartiallySignedInModalPresenter.new(view_context: self, expiration: expires_at)
    end
  end
end
