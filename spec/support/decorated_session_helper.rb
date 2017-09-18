module DecoratedSessionHelper
  def decorated_session
    sp = build_stubbed(
      :service_provider,
      friendly_name: 'Awesome Application!',
      return_to_sp_url: 'www.awesomeness.com'
    )
    view_context = ActionController::Base.new.view_context
    @decorated_session = DecoratedSession.new(
      sp: sp,
      view_context: view_context,
      sp_session: {},
      service_provider_request: ServiceProviderRequest.new
    ).call
  end
end
