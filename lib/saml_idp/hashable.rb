module SamlIdp
  module Hashable
    extend ActiveSupport::Concern

    def hashables
      self.class.hashables
    end

    def to_h
      hashables.reduce({}) do |hash, key|
        hash[key.to_sym] = send(key)
        hash
      end
    end

    module ClassMethods
      def hashables
        @hashables ||= Set.new
      end

      def hashable(method_name)
        self.hashables << method_name.to_s
      end
    end
  end
end
