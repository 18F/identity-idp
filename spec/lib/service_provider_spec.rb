require 'rails_helper'
require 'service_provider'

describe ServiceProvider do
  include SamlAuthHelper

  describe '#metadata' do
    shared_examples 'invalid service provider' do
      it 'returns nil values for all non-hardcoded keys' do
        attributes = {
          acs_url: nil,
          assertion_consumer_logout_service_url: nil,
          sp_initiated_login_url: nil,
          metadata_url: nil,
          cert: nil,
          block_encryption: 'aes256-cbc',
          key_transport: 'rsa-oaep-mgf1p',
          fingerprint: nil,
          double_quote_xml_attribute_values: true,
          agency: nil,
          friendly_name: nil
        }

        expect(@service_provider.metadata).to eq attributes
      end
    end

    context 'when the service provider is defined in the YAML' do
      it 'returns a hash with all possible keys and values that are predefined or from YAML' do
        service_provider = ServiceProvider.new('http://localhost:3000')

        attributes = {
          acs_url: 'http://localhost:3000/test/saml/decode_assertion',
          assertion_consumer_logout_service_url: 'http://localhost:3000/test/saml/decode_slo_request',
          sp_initiated_login_url: 'http://localhost:3000/test/saml',
          metadata_url: nil,
          cert: File.read("#{Rails.root}/certs/sp/saml_test_sp.crt"),
          block_encryption: 'none',
          key_transport: 'rsa-oaep-mgf1p',
          fingerprint: fingerprint,
          double_quote_xml_attribute_values: true,
          agency: 'test_agency',
          friendly_name: 'test_friendly_name'
        }

        expect(service_provider.metadata).to eq attributes
      end
    end

    context 'when the service provider is not defined in the YAML' do
      before { @service_provider = ServiceProvider.new('invalid_host') }

      it_behaves_like 'invalid service provider'
    end

    context 'when the app is running on a superb legit domain' do
      before do
        allow(Figaro.env).to receive(:domain_name).and_return('superb.legit.domain.gov')
      end

      context 'when the host is valid in the current env but not on the legit domain' do
        before { @service_provider = ServiceProvider.new('http://test.host') }

        it_behaves_like 'invalid service provider'
      end

      context 'when the host is valid on the legit domain' do
        it 'uses the config from the domain_name key' do
          service_provider = ServiceProvider.new('urn:govheroku:serviceprovider')
          acls_url = 'https://vets.gov/api/saml/logout'

          attributes = {
            acs_url: 'https://vets.gov/users/auth/saml/callback',
            assertion_consumer_logout_service_url: acls_url,
            block_encryption: 'aes256-cbc',
            cert: File.read("#{Rails.root}/certs/sp/saml_test_sp.crt"),
            double_quote_xml_attribute_values: true,
            fingerprint: fingerprint,
            key_transport: 'rsa-oaep-mgf1p',
            metadata_url: nil,
            sp_initiated_login_url: nil,
            agency: 'test_agency',
            friendly_name: nil
          }

          expect(service_provider.metadata).to eq attributes
        end
      end
    end
  end

  describe '#acs_url' do
    it 'returns the value specified in the YAML' do
      service_provider = ServiceProvider.new('http://localhost:3000')

      expect(service_provider.acs_url).to eq 'http://localhost:3000/test/saml/decode_assertion'
    end
  end

  describe '#assertion_consumer_logout_service_url' do
    context 'when no value is specified in YAML' do
      it 'returns nil' do
        service_provider = ServiceProvider.new('http://test.host')

        expect(service_provider.assertion_consumer_logout_service_url).to be_nil
      end
    end

    context 'when value is specified in YAML' do
      it 'returns the value from YAML' do
        service_provider = ServiceProvider.new(
          'https://rp1.serviceprovider.com/auth/saml/metadata'
        )

        expect(service_provider.assertion_consumer_logout_service_url).
          to eq 'http://example.com/test/saml/decode_slo_request'
      end
    end
  end

  describe '#sp_initiated_login_url' do
    context 'when no value is specified in YAML' do
      it 'returns nil' do
        service_provider = ServiceProvider.new(
          'https://uscis.serviceprovider.com/auth/saml/metadata'
        )

        expect(service_provider.sp_initiated_login_url).to be_nil
      end
    end

    context 'when value is specified in YAML' do
      it 'returns the value from YAML' do
        service_provider = ServiceProvider.new('http://localhost:3000')

        expect(service_provider.sp_initiated_login_url).
          to eq 'http://localhost:3000/test/saml'
      end
    end
  end

  describe '#metadata_url' do
    context 'when value is not specified in YAML' do
      it 'returns nil' do
        service_provider = ServiceProvider.new('http://localhost:3000')

        expect(service_provider.metadata_url).to be_nil
      end
    end

    context 'when value is specified in YAML' do
      it 'returns the value from YAML' do
        service_provider = ServiceProvider.new('http://test.host')

        expect(service_provider.metadata_url).
          to eq 'http://test.host/test/saml/metadata'
      end
    end
  end

  describe '#agency' do
    context 'when value is not specified in YAML' do
      it 'returns nil' do
        service_provider = ServiceProvider.new('http://test.host')

        expect(service_provider.agency).to be_nil
      end
    end

    context 'when value is specified in YAML' do
      it 'returns the value from YAML' do
        service_provider = ServiceProvider.new('http://localhost:3000')

        expect(service_provider.agency).
          to eq 'test_agency'
      end
    end
  end

  describe '#friendly_name' do
    context 'when value is not specified in YAML' do
      it 'returns nil' do
        service_provider = ServiceProvider.new('http://test.host')

        expect(service_provider.friendly_name).to be_nil
      end
    end

    context 'when value is specified in YAML' do
      it 'returns the value from YAML' do
        service_provider = ServiceProvider.new('http://localhost:3000')

        expect(service_provider.friendly_name).
          to eq 'test_friendly_name'
      end
    end
  end

  describe '#cert' do
    it 'returns nil when no cert is specified' do
      service_provider = ServiceProvider.new('http://test.host')

      expect(service_provider.cert).to be_nil
    end

    it 'reads the cert from the value specified in the YAML' do
      service_provider = ServiceProvider.new('http://localhost:3000')

      expect(service_provider.cert).to eq File.read("#{Rails.root}/certs/sp/saml_test_sp.crt")
    end
  end

  describe '#block_encryption' do
    context 'when no value is specified in YAML' do
      it 'returns "aes256-cbc"' do
        service_provider = ServiceProvider.new('http://test.host')

        expect(service_provider.block_encryption).to eq 'aes256-cbc'
      end
    end

    context 'when value is specified in YAML' do
      it 'returns the value from YAML' do
        service_provider = ServiceProvider.new(
          'https://rp1.serviceprovider.com/auth/saml/metadata'
        )

        expect(service_provider.block_encryption).to eq 'aes256-cbc'
      end
    end
  end

  describe '#key_transport' do
    it 'returns a hardcoded value' do
      service_provider = ServiceProvider.new('http://localhost:3000')

      expect(service_provider.key_transport).to eq 'rsa-oaep-mgf1p'
    end
  end

  describe '#fingerprint' do
    it 'returns a hex digest' do
      service_provider = ServiceProvider.new('http://localhost:3000')

      expect(service_provider.fingerprint).to eq fingerprint
    end
  end

  describe '#double_quote_xml_attribute_values' do
    it 'returns a hardcoded value' do
      service_provider = ServiceProvider.new('http://localhost:3000')

      expect(service_provider.double_quote_xml_attribute_values).to eq true
    end
  end
end
