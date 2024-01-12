module Idv
  module PluginAware
    extend ActiveSupport::Concern

    included do
      define_method :plugin_manager do
        PluginManager.instance
      end

      def self.require_plugin(plugin_label)
        before_action do |controller|
          if !plugin_manager.plugin_registered?(plugin_label)
            render_not_found
          end
        end
      end
    end
  end
end
