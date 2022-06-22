class BaseComponent < ViewComponent::Base
  def before_render
    render_scripts
  end

  def self.scripts
    @scripts ||= _sidecar_files(['js', 'ts']).map { |file| File.basename(file, '.*') }
  end

  def scripts
    self.class.scripts
  end

  def unique_id
    @unique_id ||= SecureRandom.hex(4)
  end

  private

  def render_scripts
    return if @rendered_scripts
    @rendered_scripts = true
    return unless helpers.respond_to?(:enqueue_component_scripts)
    helpers.enqueue_component_scripts(*scripts) if scripts.present?
  end
end
