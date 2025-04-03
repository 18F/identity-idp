# frozen_string_literal: true

class SamlEndpoint
  SAML_YEARS = IdentityConfig.store.saml_endpoint_configs.map do |config|
    config.fetch(:suffix).to_s
  end.uniq.sort.freeze

  attr_reader :year

  def initialize(year)
    @year = year
  end

  def self.valid_year?(year)
    SAML_YEARS.include?(year)
  end

  def self.suffixes
    SAML_YEARS
  end

  def self.build_saml_keys_by_year
    SAML_YEARS.each_with_object({}) do |year, map|
      config = IdentityConfig.store.saml_endpoint_configs.find do |config|
        config[:suffix] == year
      end

      key_contents = begin
        AppArtifacts.store["saml_#{year}_key"]
      rescue NameError
        raise "No SAML private key for suffix #{year}"
      end

      map[year] =
        begin
          OpenSSL::PKey::RSA.new(
            key_contents,
            config.fetch(:secret_key_passphrase),
          )
        rescue OpenSSL::PKey::RSAError
          raise "SAML key or passphrase for #{year} is invalid"
        end
    end
  end

  def self.build_saml_certs_by_year
    SAML_YEARS.each_with_object({}) do |year, map|
      x509_cert =
        begin
          cert_string = AppArtifacts.store["saml_#{year}_cert"]
          # Validate string value can be parsed to X509, but store string
          OpenSSL::X509::Certificate.new(cert_string)
          cert_string
        rescue NameError
          raise "No SAML certificate for suffix #{year}"
        rescue OpenSSL::X509::CertificateError
          raise "SAML certificate for #{year} is invalid"
        end
      map[year] = x509_cert
    end
  end

  def secret_key
    SAML_YEAR_SECRET_KEYS.fetch(year)
  rescue KeyError
    raise "No SAML private key for suffix #{year}"
  end

  def x509_certificate
    SAML_YEAR_CERTS.fetch(year)
  rescue KeyError
    raise "No SAML certificate for suffix #{year}"
  end

  def saml_metadata
    config = SamlIdp.config.dup
    config.single_service_post_location += year

    SamlIdp::MetadataBuilder.new(
      config,
      x509_certificate,
      secret_key,
    )
  end

  SAML_YEAR_CERTS = self.build_saml_certs_by_year.freeze

  SAML_YEAR_SECRET_KEYS = self.build_saml_keys_by_year.freeze
end
