require 'rails_helper'

describe SamlIdpEncryptionConfigurator do
  describe 'configure' do
    let(:config) { SamlIdp::Configurator.new }

    context 'when cloudhsm is disabled' do
      before do
        allow(Figaro.env).to receive(:cloudhsm_enabled).and_return('false')
      end

      it 'sets the secret saml key if cloudhsm is not enabled' do
        SamlIdpEncryptionConfigurator.configure(config)
        expect(config.secret_key).to eq(RequestKeyManager.private_key.to_pem)
      end
    end

    context 'when cloudhsm is enabled' do
      before do
        allow(Figaro.env).to receive(:cloudhsm_enabled).and_return('true')
      end

      it 'sets the secret_key to the app config cloudhsm_saml_key_label' do
        SamlIdpEncryptionConfigurator.configure(config)
        expect(config.secret_key).to eq(Figaro.env.cloudhsm_saml_key_label)
      end

      it 'sets cloudhsm_enabled to true' do
        SamlIdpEncryptionConfigurator.configure(config)
        expect(config.cloudhsm_enabled).to eq(true)
      end

      it 'sets cloudhsm_pin to the app config cloudhsm_pin' do
        SamlIdpEncryptionConfigurator.configure(config)
        expect(config.cloudhsm_pin).to eq(Figaro.env.cloudhsm_pin)
      end
    end
  end
end
