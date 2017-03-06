class DecoratedSession
  def initialize(sp:, view_context:)
    @sp = sp
    @view_context = view_context
  end

  def call
    if sp.is_a? ServiceProvider
      ServiceProviderSessionDecorator.new(sp: sp, view_context: view_context)
    else
      SessionDecorator.new
    end
  end

  private

  attr_reader :sp, :view_context
end
