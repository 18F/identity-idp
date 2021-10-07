class BaseComponent < ViewComponent::Base
  class << self
    def renders_script(script = self.name.underscore)
      define_method 'render_in' do |view_context, &block|
        if view_context.respond_to?(:render_component_script)
          view_context.render_component_script(script)
        end

        super(view_context, &block)
      end
    end
  end
end
