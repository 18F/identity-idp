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

  describe '#destroy' do
    let(:user) { create(:user, :signed_up) }
    let(:phone_configuration) { create(:phone_configuration, user: user) }

    it 'deletes the phone configuration' do
      stub_sign_in(user.reload)
      # Receives twice because one is sent when signing up with a second factor
      expect(PushNotification::HttpPush).to receive(:deliver).
        with(PushNotification::RecoveryInformationChangedEvent.new(user: user)).twice
      delete :destroy, params: { id: phone_configuration.id }

      expect(response).to redirect_to(account_url)
      expect(flash[:success]).to eq(t('two_factor_authentication.phone.delete.success'))
      expect(PhoneConfiguration.find_by(id: phone_configuration.id)).to eq(nil)
    end

    context 'when the user will not have enough phone configurations after deleting' do
      let(:user) { create(:user, :with_phone) }
      let(:phone_configuration) { user.phone_configurations.first }

      it 'does not delete the phone configuration' do
        stub_sign_in(user)
        delete :destroy, params: { id: phone_configuration.id }

        expect(response).to redirect_to(account_url)
        expect(flash[:error]).to eq(t('two_factor_authentication.phone.delete.failure'))
        expect(PhoneConfiguration.find_by(id: phone_configuration.id)).to eq(phone_configuration)
      end
    end
  end
end
