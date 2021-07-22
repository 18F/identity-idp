class DecoratedSession
  def initialize(sp:, view_context:, sp_session:, service_provider_request:)
    @sp = sp
    @view_context = view_context
    @sp_session = sp_session
    @service_provider_request = service_provider_request
  end

  def call
    if sp
      ServiceProviderSessionDecorator.new(
        sp: sp,
        view_context: view_context,
        sp_session: sp_session,
        service_provider_request: service_provider_request,
      )
    else
      SessionDecorator.new(view_context: view_context)
    end
  end

  private

  attr_reader :sp, :view_context, :sp_session, :service_provider_request
end
