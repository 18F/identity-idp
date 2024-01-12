module Idv
  module PluginAware
    extend ActiveSupport::Concern

    included do
      def self.require_plugin(*args)
      end
    end
  end
end
