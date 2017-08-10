require 'rails_helper'

include Features::MailerHelper
include Features::LocalizationHelper

describe Users::PhonesController do
  describe '#phone' do
    let(:user) { create(:user, :signed_up, phone: '+1 (202) 555-1234') }
    let(:second_user) { create(:user, :signed_up, phone: '+1 (202) 555-5678') }
    let(:new_phone) { '555-555-5555' }

    context 'user changes phone' do
      before do
        stub_sign_in(user)

        stub_analytics
        allow(@analytics).to receive(:track_event)

        put :update, params: {
          user_phone_form: { phone: new_phone,
                             international_code: 'US',
                             otp_delivery_preference: 'sms' },
        }
      end

      it 'lets user know they need to confirm their new phone' do
        expect(flash[:notice]).to eq t('devise.registrations.phone_update_needs_confirmation')
        expect(user.reload.phone).to_not eq '+1 (555) 555-5555'
        expect(@analytics).to have_received(:track_event).
          with(Analytics::PHONE_CHANGE_REQUESTED)
        expect(response).to redirect_to(
          otp_send_path(
            otp_delivery_selection_form: { otp_delivery_preference: 'sms' }
          )
        )
        expect(subject.user_session[:context]).to eq 'confirmation'
      end
    end

    context 'user enters an empty phone' do
      it 'does not delete the phone' do
        stub_sign_in(user)

        put :update, params: {
          user_phone_form: { phone: '',
                             international_code: 'US',
                             otp_delivery_preference: 'sms' },
        }

        expect(user.reload.phone).to be_present
        expect(response).to render_template(:edit)
      end
    end

    context "user changes phone to another user's phone" do
      before do
        stub_sign_in(user)

        stub_analytics
        allow(@analytics).to receive(:track_event)

        put :update, params: {
          user_phone_form: { phone: second_user.phone,
                             international_code: 'US',
                             otp_delivery_preference: 'sms' },
        }
      end

      it 'processes successfully and informs user' do
        expect(flash[:notice]).to eq t('devise.registrations.phone_update_needs_confirmation')
        expect(user.reload.phone).to_not eq second_user.phone
        expect(@analytics).to have_received(:track_event).
          with(Analytics::PHONE_CHANGE_REQUESTED)
        expect(response).to redirect_to(
          otp_send_path(
            otp_delivery_selection_form: { otp_delivery_preference: 'sms' }
          )
        )
        expect(subject.user_session[:context]).to eq 'confirmation'
      end
    end

    context 'user updates with invalid phone' do
      it 'does not change the user phone number' do
        invalid_phone = '123'
        user = build(:user, phone: '123-123-1234')
        stub_sign_in(user)

        put :update, params: {
          user_phone_form: { phone: invalid_phone,
                             international_code: 'US',
                             otp_delivery_preference: 'sms' },
        }

        expect(user.phone).not_to eq invalid_phone
        expect(response).to render_template(:edit)
      end
    end

    context 'user submits the form without changing their phone' do
      it 'redirects to profile page without any messages' do
        stub_sign_in(user)

        put :update, params: {
          user_phone_form: { phone: user.phone,
                             international_code: 'US',
                             otp_delivery_preference: 'sms' },
        }

        expect(response).to redirect_to account_url
        expect(flash.keys).to be_empty
      end
    end
  end
end
