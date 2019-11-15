require 'rails_helper'

describe Users::EditPhoneController do
  describe '#update' do
    let(:user) { create(:user, :signed_up) }
    let(:phone_configuration) { user.phone_configurations.first }

    before do
      stub_sign_in(user)
    end

    context 'when the user submits a valid otp delivery preference' do
      it 'updates the phone configuration and redirects' do
        put :update, params: {
          id: phone_configuration.id,
          edit_phone_form: { delivery_preference: 'voice' },
        }

        expect(response).to redirect_to(account_url)
        expect(phone_configuration.reload.delivery_preference).to eq('voice')
      end
    end

    context 'when the user submits an invalid delivery preference' do
      it 'renders the edit screen' do
        put :update, params: {
          id: phone_configuration.id,
          edit_phone_form: { delivery_preference: 'noise' },
        }

        expect(response).to render_template(:edit)
        expect(phone_configuration.reload.delivery_preference).to eq('sms')
      end
    end
  end
end
