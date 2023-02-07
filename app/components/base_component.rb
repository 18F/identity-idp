class BaseComponent < ViewComponent::Base
  def before_render
    return if @rendered_scripts
    @rendered_scripts = true
    if helpers.respond_to?(:enqueue_component_scripts) && self.class.scripts.present?
      helpers.enqueue_component_scripts(*self.class.scripts)
    end
  end

  def self.scripts
    @scripts ||= begin
      scripts = _sidecar_files(['js', 'ts']).map { |file| File.basename(file, '.*') }
      scripts.concat superclass.scripts if superclass.respond_to?(:scripts)
      scripts
    end
  end

  def unique_id
    @unique_id ||= SecureRandom.hex(4)
  end
end
