# frozen_string_literal: true

class BaseComponent < ViewComponent::Base
  def before_render
    render_assets unless rendered_assets?
  end

  def self.scripts
    @scripts ||= begin
      scripts = sidecar_files_basenames(['js', 'ts'])
      scripts.concat superclass.scripts if superclass.respond_to?(:scripts)
      scripts
    end
  end

  def self.stylesheets
    @stylesheets ||= begin
      stylesheets = sidecar_files_basenames(['scss'])
      stylesheets.concat superclass.stylesheets if superclass.respond_to?(:stylesheets)
      stylesheets
    end
  end

  def unique_id
    @unique_id ||= SecureRandom.hex(4)
  end

  private

  attr_accessor :rendered_assets
  alias_method :rendered_assets?, :rendered_assets

  class << self
    def sidecar_files_basenames(extensions)
      sidecar_files(extensions).map { |file| File.basename(file, '.*') }
    end
  end

  def render_assets
    if helpers.respond_to?(:enqueue_component_scripts) && self.class.scripts.present?
      helpers.enqueue_component_scripts(*self.class.scripts)
    end

    if helpers.respond_to?(:enqueue_component_stylesheets) && self.class.stylesheets.present?
      helpers.enqueue_component_stylesheets(*self.class.stylesheets)
    end

    @rendered_assets = true
  end
end
