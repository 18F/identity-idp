require 'rails_helper'

describe SamlIdpEncryptionConfigurator do
  describe 'configure' do
    let(:config) { SamlIdp::Configurator.new }

    context 'when cloudhsm is disabled' do
      before(:example) do
        SamlIdpEncryptionConfigurator.configure(config, false)
      end

      it 'sets cloudhsm_enabled to false' do
        expect(config.cloudhsm_enabled).to eq(false)
      end

      it 'sets the secret key' do
        expect(config.secret_key).to eq(RequestKeyManager.private_key.to_pem)
      end
    end

    context 'when cloudhsm is enabled' do
      before(:example) do
        SamlIdpEncryptionConfigurator.configure(config, true)
      end

      it 'sets the secret_key to the app config cloudhsm_saml_key_label' do
        expect(config.secret_key).to eq(Figaro.env.cloudhsm_saml_key_label)
      end

      it 'sets cloudhsm_enabled to true' do
        expect(config.cloudhsm_enabled).to eq(true)
      end

      it 'sets cloudhsm_pin to the app config cloudhsm_pin' do
        expect(config.cloudhsm_pin).to eq(Figaro.env.cloudhsm_pin)
      end
    end
  end
end
