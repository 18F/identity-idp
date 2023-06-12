require 'rails_helper'

RSpec.describe SamlEndpoint do
  let(:year) { '2023' }

  subject { described_class.new(year) }

  describe '.suffixes' do
    it 'should list the suffixes that are configured' do
      result = described_class.suffixes

      expect(result).to eq(%w[2023 2022])
    end
  end

  describe 'endpoint_configs' do
    it 'should return an array of parsed endpoint config data' do
      result = described_class.endpoint_configs

      expect(result).to eq(
        [
          { suffix: '2023', secret_key_passphrase: 'trust-but-verify' },
          {
            # rubocop:disable Layout/LineLength
            comment: 'this extra year is needed to demonstrate how handling multiple live years works in spec/requests/saml_requests_spec.rb',
            # rubocop:enable Layout/LineLength
            secret_key_passphrase: 'trust-but-verify',
            suffix: '2022',
          },
        ],
      )
    end
  end

  describe '#secret_key' do
    it 'returns the key loaded from the file system' do
      expect(
        subject.secret_key.to_pem,
      ).to eq(
        OpenSSL::PKey::RSA.new(
          AppArtifacts.store.saml_2023_key,
          'trust-but-verify',
        ).to_pem,
      )
    end

    context 'when the key file does not exist' do
      let(:year) { '_dne' }

      before do
        allow(SamlEndpoint).to receive(:endpoint_configs).and_return(
          [
            { suffix: '_dne', secret_key_passphrase: 'asdf1234' },
          ],
        )
      end

      it 'raises an error' do
        expect { subject.secret_key }.to raise_error(
          'No SAML private key for suffix _dne',
        )
      end
    end
  end

  describe '#x509_certificate' do
    it 'returns the x509 cert loaded from the filesystem' do
      expect(
        subject.x509_certificate,
      ).to eq(
        AppArtifacts.store.saml_2023_cert,
      )
    end
  end

  describe '#saml_metadata' do
    it 'returns the saml metadata with the suffix added to the urls' do
      result = subject.saml_metadata

      expect(result.configurator.single_service_post_location).to match(%r{api/saml/auth2023\Z})
    end

    it 'does not include the SingLogoutService endpoints when configured' do
      allow(IdentityConfig.store).to receive(:include_slo_in_saml_metadata).
        and_return(false)
      result = subject.saml_metadata

      expect(result.configurator.single_logout_service_post_location).to be_nil
      expect(result.configurator.remote_logout_service_post_location).to be_nil
    end

    it 'includes the SingLogoutService endpoints when configured' do
      allow(IdentityConfig.store).to receive(:include_slo_in_saml_metadata).
        and_return(true)
      result = subject.saml_metadata

      expect(result.configurator.single_logout_service_post_location).to match(
        %r{api/saml/logout2023\Z},
      )
      expect(result.configurator.remote_logout_service_post_location).to match(
        %r{api/saml/remotelogout2023\Z},
      )
    end
  end
end
