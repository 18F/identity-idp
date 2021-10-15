class BaseComponent < ViewComponent::Base
  def render_in(view_context, &block)
    render_scripts_in(view_context)
    super(view_context, &block)
  end

  def render_scripts_in(view_context)
    return if @rendered_scripts
    @rendered_scripts = true
    if view_context.respond_to?(:render_component_script) && self.class.scripts.present?
      view_context.render_component_script(*self.class.scripts)
    end
  end

  def self.scripts
    @scripts ||= _sidecar_files(['js']).map { |file| File.basename(file, '.js') }
  end
end
