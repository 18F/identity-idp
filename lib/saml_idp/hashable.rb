module SamlIdp
  module Hashable
    extend ActiveSupport::Concern

    def hashables
      self.class.hashables
    end

    def to_h
      hashables.each_with_object({}) do |key, hash|
        hash[key.to_sym] = send(key)
      end
    end

    module ClassMethods
      def hashables
        @hashables ||= Set.new
      end

      def hashable(method_name)
        hashables << method_name.to_s
      end
    end
  end
end
