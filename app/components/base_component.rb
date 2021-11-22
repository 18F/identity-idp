class BaseComponent < ViewComponent::Base
  def before_render
    return if @rendered_scripts
    @rendered_scripts = true
    if helpers.respond_to?(:enqueue_component_scripts) && self.class.scripts.present?
      helpers.enqueue_component_scripts(*self.class.scripts)
    end
  end

  def self.scripts
    @scripts ||= _sidecar_files(['js']).map { |file| File.basename(file, '.js') }
  end
end
