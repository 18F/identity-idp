class BaseComponent < ViewComponent::Base
  def before_render
    render_assets unless rendered_assets?
  end

  def self.scripts
    @scripts ||= sidecar_files_basenames(['js', 'ts'])
  end

  def self.stylesheets
    @stylesheets ||= sidecar_files_basenames(['scss'])
  end

  def unique_id
    @unique_id ||= SecureRandom.hex(4)
  end

  private

  class << self
    def sidecar_files_basenames(extensions)
      _sidecar_files(extensions).map { |file| File.basename(file, '.*') }
    end
  end

  def render_assets
    if helpers.respond_to?(:enqueue_component_scripts) && self.class.scripts.present?
      helpers.enqueue_component_scripts(*self.class.scripts)
    end

    if helpers.respond_to?(:enqueue_component_stylesheets) && self.class.stylesheets.present?
      helpers.enqueue_component_stylesheets(*self.class.stylesheets)
    end

    @has_rendered_assets = true
  end

  def rendered_assets?
    @has_rendered_assets
  end
end
