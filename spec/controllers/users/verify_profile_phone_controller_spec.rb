require 'rails_helper'

RSpec.describe Users::VerifyProfilePhoneController do
  include Features::LocalizationHelper

  let(:has_pending_profile) { true }
  let(:user) { create(:user) }
  let(:profile_phone) { user.phone }
  let(:phone_confirmed) { false }
  let(:pii_attributes) { Pii::Attributes.new_from_hash(phone: profile_phone) }
  let(:pending_profile) { build(:profile, phone_confirmed: phone_confirmed) }

  before do
    stub_sign_in(user)
    decorated_user = stub_decorated_user_with_pending_profile(user)
    allow(decorated_user).to receive(:needs_profile_phone_verification?).
      and_return(has_pending_profile)
    allow(decorated_user).to receive(:needs_profile_usps_verification?).and_return(false)
    allow(controller).to receive(:decrypted_pii).and_return(pii_attributes)
  end

  describe '#index' do
    context 'user has pending profile' do
      context 'phone is not confirmed' do
        it 'redirects to profile page' do
          get :index

          expect(response).to redirect_to(account_url)
        end
      end

      context 'phone is confirmed and different than 2FA' do
        let(:profile_phone) { '703-555-9999' }
        let(:phone_confirmed) { true }

        it 'redirects to OTP confirmation flow' do
          get :index

          expect(response).to redirect_to(
            otp_send_path(otp_delivery_selection_form: { otp_delivery_preference: 'sms' })
          )
        end
      end
    end

    context 'user does not have pending profile' do
      let(:has_pending_profile) { false }

      it 'redirects to profile page' do
        get :index

        expect(response).to redirect_to(account_url)
      end
    end
  end
end
