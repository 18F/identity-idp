# encoding: utf-8
module SamlIdp
  class Configurator
    attr_accessor :x509_certificate
    attr_accessor :secret_key
    attr_accessor :algorithm
    attr_accessor :organization_name
    attr_accessor :organization_url
    attr_accessor :base_saml_location
    attr_accessor :reference_id_generator
    attr_accessor :attribute_service_location

    attr_accessor :single_service_post_location
    # name_id_formats:
    #   [:email_address, :transient] # All 2.0
    #   {
    #     "1.1" => [:email_address],
    #     "2.0" => [:transient]
    #   }
    attr_accessor :name_id_formats
    # attributes:
    #   {
    #     <friendly_name> => {        # required (ex "eduPersonAffiliation")
    #       "name" => <attrname>      # required (ex "urn:oid:1.3.6.1.4.1.5923.1.1.1.1")
    #       "name_format" => "urn:oasis:names:tc:SAML:2.0:attrname-format:uri", # not required
    #       "values" => [ # not required
    #         "memeber", (ex)
    #         "student", (ex)
    #       ]
    #    }
    attr_accessor :attributes

    def initialize(config_file = nil)
      self.x509_certificate = Default::X509_CERTIFICATE
      self.secret_key = Default::SECRET_KEY
      self.algorithm = :sha1
      self.reference_id_generator = ->() { UUID.generate }
      self.attributes = []
      instance_eval(File.read(config_file), config_file) if config_file
    end

    # company
    # given_name
    # sur_name
    # email_address
    # telephone
    def technical_contact
      @technical_contact ||= TechnicalContact.new
    end

    class TechnicalContact < OpenStruct
      def mail_to_string
        "mailto:#{email_address}" if email_address.to_s.length > 0
      end
    end
  end
end
