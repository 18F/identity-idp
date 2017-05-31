class DecoratedSession
  def initialize(sp:, view_context:, sp_session:)
    @sp = sp
    @view_context = view_context
    @sp_session = sp_session
  end

  def call
    if sp.is_a? ServiceProvider
      ServiceProviderSessionDecorator.new(
        sp: sp, view_context: view_context, sp_session: sp_session
      )
    else
      SessionDecorator.new
    end
  end

  private

  attr_reader :sp, :view_context, :sp_session
end
