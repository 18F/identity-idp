# Requires methods:
#   * reference_id
#   * raw
#   * digest
#   * algorithm
#   * rebuild
module SamlIdp
  module Signable
    def self.included(base)
      base.extend ClassMethods
      base.send :attr_accessor, :signature
    end

    def signed
      dup.tap { |dupd|
        dupd.signature = build_signature
      }.send(self.class.rebuild_method)
    end

    def build_signature
      SignatureBuilder.new(signed_info_builder).raw
    end
    private :build_signature

    def signed_info_builder
      SignedInfoBuilder.new(get_reference_id, get_digest, get_algorithm)
    end
    private :signed_info_builder

    def get_reference_id
      send(self.class.reference_id_method)
    end
    private :get_reference_id

    def get_digest
      send(self.class.digest_method)
    end
    private :get_digest

    def get_algorithm
      send(self.class.algorithm_method)
    end
    private :get_algorithm

    def get_raw
      send(self.class.raw_method)
    end
    private :get_raw

    def digest
      Base64.encode64(algorithm.digest(get_raw)).gsub(/\n/, '')
    end
    private :digest

    module ClassMethods
      def self.module_method(name, default = nil)
        default ||= name
        define_method "#{name}_method" do |new_method_name = nil|
          instance_variable_set("@#{name}", new_method_name) if new_method_name
          instance_variable_get("@#{name}") || default
        end
      end
      module_method :rebuild
      module_method :raw
      module_method :digest
      module_method :algorithm
      module_method :reference_id
    end
  end
end
