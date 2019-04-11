require 'rails_helper'

describe WebauthnSetupForm do
  include WebAuthnHelper

  let(:user) { create(:user) }
  let(:user_session) { { webauthn_challenge: webauthn_challenge } }
  let(:subject) { WebauthnSetupForm.new(user, user_session) }

  describe '#submit' do
    context 'when the input is valid' do
      it 'returns FormResponse with success: true' do
        allow(Figaro.env).to receive(:domain_name).and_return('localhost:3000')
        result = instance_double(FormResponse)
        params = {
          attestation_object: attestation_object,
          client_data_json: setup_client_data_json,
          name: 'mykey',
        }
        extra_attributes = {
          mfa_method_counts: { webauthn: 1 },
          multi_factor_auth_method: 'webauthn',
        }

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra_attributes).and_return(result)
        expect(subject.submit(protocol, params)).to eq result
      end
    end

    context 'when the input is invalid' do
      it 'returns FormResponse with success: false' do
        result = instance_double(FormResponse)
        params = {
          attestation_object: attestation_object,
          client_data_json: setup_client_data_json,
          name: 'mykey',
        }
        extra_attributes = {
          mfa_method_counts: {},
          multi_factor_auth_method: 'webauthn',
        }

        expect(FormResponse).to receive(:new).
          with(success: false, errors: {}, extra: extra_attributes).and_return(result)
        expect(subject.submit(protocol, params)).to eq result
      end

      it 'returns false with an error when the attestation response raises an error' do
        allow(Figaro.env).to receive(:domain_name).and_return('localhost:3000')
        allow(WebAuthn::AttestationStatement).to receive(:from).and_raise(StandardError)

        result = instance_double(FormResponse)
        params = {
          attestation_object: attestation_object,
          client_data_json: setup_client_data_json,
          name: 'mykey',
        }
        extra_attributes = {
          mfa_method_counts: {},
          multi_factor_auth_method: 'webauthn',
        }

        expect(FormResponse).to receive(:new).
          with(success: false, extra: extra_attributes, errors:
            { name: [I18n.t('errors.webauthn_setup.attestation_error')] }).and_return(result)
        expect(subject.submit(protocol, params)).to eq result
      end
    end
  end
end
