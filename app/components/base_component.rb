class BaseComponent < ViewComponent::Base
  class << self
    def renders_script(script = self.name.underscore)
      define_method 'render_in' do |view_context, &block|
        view_context.javascript_packs_tag_once(script)
        super(view_context, &block)
      end
    end
  end
end
