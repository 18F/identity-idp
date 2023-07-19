module SessionTimeoutWarningHelper
  def session_timeout_warning
    IdentityConfig.store.session_timeout_warning_seconds
  end

  def timeout_refresh_path
    UriService.add_params(
      request.original_fullpath,
      timeout: :form,
    )&.html_safe # rubocop:disable Rails/OutputSafety
  end

  def session_modal
    SessionTimeoutModalPresenter.new(user_fully_authenticated: user_fully_authenticated?)
  end
end
