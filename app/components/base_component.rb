class BaseComponent < ViewComponent::Base
  @rendered_scripts = []

  class << self
    attr_accessor :rendered_scripts

    def renders_script(script = self.name.underscore)
      define_method 'render_in' do |view_context, &block|
        BaseComponent.rendered_scripts |= [script]
        super(view_context, &block)
      end
    end
  end
end
