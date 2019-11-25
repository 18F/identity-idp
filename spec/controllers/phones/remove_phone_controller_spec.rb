require 'rails_helper'

describe Phones::RemovePhoneController do
  describe '#destroy' do
    let(:user) { create(:user, :signed_up) }
    let(:phone_configuration) { create(:phone_configuration, user: user) }

    it 'deletes the phone configuraiton' do
      stub_sign_in(user.reload)
      delete :destroy, params: { id: phone_configuration.id }

      expect(response).to redirect_to(account_url)
      expect(flash[:success]).to eq(t('two_factor_authentication.phone.delete.success'))
      expect(PhoneConfiguration.find_by(id: phone_configuration.id)).to eq(nil)
    end

    context 'when the user will not have enough phone configurations after deleting' do
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
