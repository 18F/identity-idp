require 'rails_helper'

describe WebauthnVerificationForm do
  include WebauthnVerificationHelper

  let(:user) { create(:user) }
  let(:user_session) { { webauthn_challenge: challenge } }
  let(:subject) { WebauthnVerificationForm.new(user, user_session) }

  describe '#submit' do
    before do
      create_webauthn_configuration(user)
    end
    context 'when the input is valid' do
      it 'returns FormResponse with success: true' do
        allow(Figaro.env).to receive(:domain_name).and_return('localhost:3000')
        result = instance_double(FormResponse)
        params = {
          authenticator_data: authenticator_data,
          client_data_json: client_data_json,
          signature: signature,
          credential_id: credential_id,
        }
        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: { multi_factor_auth_method: 'webauthn' }).
          and_return(result)
        expect(subject.submit(protocol, params)).to eq result
      end
    end

    context 'when the input is invalid' do
      it 'returns FormResponse with success: false' do
        result = instance_double(FormResponse)
        params = {
          authenticator_data: authenticator_data,
          client_data_json: client_data_json,
          signature: signature,
          credential_id: credential_id,
        }
        expect(FormResponse).to receive(:new).
          with(success: false, errors: {}, extra: { multi_factor_auth_method: 'webauthn' }).
          and_return(result)
        expect(subject.submit(protocol, params)).to eq result
      end
    end
  end
end
