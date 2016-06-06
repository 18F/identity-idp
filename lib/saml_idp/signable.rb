# Requires methods:
#   * reference_id
#   * raw
#   * digest
#   * algorithm
require 'saml_idp/signed_info_builder'
require 'saml_idp/signature_builder'
module SamlIdp
  module Signable
    def self.included(base)
      base.extend ClassMethods
      base.send :attr_accessor, :reference_id
    end

    def signed
      generated_reference_id do
        with_signature do
          send(self.class.raw_method)
        end
      end
    end

    def sign(el)
      el << signature if sign?
    end

    def generated_reference_id
      if reference_id
        fin = yield reference_id if block_given?
      else
        self.reference_id = ref = reference_id_generator.call
        fin = yield reference_id if block_given?
        self.reference_id = nil
      end
      block_given? ? fin : ref
    end
    private :generated_reference_id

    def reference_id_generator
      SamlIdp.config.reference_id_generator
    end
    private :reference_id_generator

    def with_signature
      original = @sign
      @sign = true
      yield.tap do
        @sign = original
      end
    end
    private :with_signature

    def without_signature
      original = @sign
      @sign = false
      yield.tap do
        @sign = original
      end
    end
    private :without_signature

    def sign?
      !!@sign
    end
    private :sign?

    def signature
      SignatureBuilder.new(signed_info_builder).raw
    end
    private :signature

    def signed_info_builder
      SignedInfoBuilder.new(get_reference_id, get_digest, get_algorithm)
    end
    private :signed_info_builder

    def get_reference_id
      send(self.class.reference_id_method)
    end
    private :get_reference_id

    def get_digest
      without_signature do
        send(self.class.digest_method)
      end
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

    def noko_raw
      Nokogiri::XML::Document.parse(get_raw)
    end
    private :noko_raw

    def digest
      # Make it check for inclusive at some point (https://github.com/onelogin/ruby-saml/blob/master/lib/xml_security.rb#L159)
      inclusive_namespaces = []
      # Also make customizable
      canon_algorithm = Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0
      canon_hashed_element = noko_raw.canonicalize(canon_algorithm, inclusive_namespaces)
      digest_algorithm = get_algorithm

      hash                          = digest_algorithm.digest(canon_hashed_element)
      Base64.strict_encode64(hash).gsub(/\n/, '')
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
      module_method :raw
      module_method :digest
      module_method :algorithm
      module_method :reference_id
    end
  end
end
