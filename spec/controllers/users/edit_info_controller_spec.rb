require 'rails_helper'

include Features::MailerHelper
include Features::LocalizationHelper

describe Users::EditInfoController, devise: true do
  describe '#mobile' do
    let(:user) { create(:user, :signed_up, mobile: '+1 (202) 555-1234') }
    let(:second_user) { create(:user, :signed_up, mobile: '+1 (202) 555-5678') }
    let(:new_mobile) { '555-555-5555' }

    context 'user changes mobile' do
      before do
        sign_in(user)
        stub_analytics
        allow(@analytics).to receive(:track_event)
        put :mobile, update_user_mobile_form: { mobile: new_mobile }
      end

      it 'redirects to phone confirmation page with success message' do
        expect(response).to redirect_to(phone_confirmation_send_path)
        expect(flash[:notice]).to eq t('devise.registrations.mobile_update_needs_confirmation')
      end

      it 'does not update the users phone number' do
        expect(user.reload.mobile).to_not eq '+1 (555) 555-5555'
      end

      it 'tracks the phone number update event' do
        expect(@analytics).to have_received(:track_event).
          with('User asked to update their phone number')
      end
    end

    context 'user attempts to remove mobile number' do
      render_views

      it 'displays error message and does not remove mobile' do
        sign_in(user)
        put :mobile, update_user_mobile_form: { mobile: '' }

        expect(response.body).to have_content invalid_mobile_message
        expect(second_user.reload.mobile).to be_present
      end
    end

    context "user changes mobile to another user's mobile" do
      it 'redirects to phone confirmation page with success message' do
        sign_in(user)
        put :mobile, update_user_mobile_form: { mobile: second_user.mobile }

        expect(response).to redirect_to(phone_confirmation_send_path)
        expect(flash[:notice]).to eq t('devise.registrations.mobile_update_needs_confirmation')
        expect(user.reload.mobile).to_not eq second_user.mobile
      end
    end

    context 'user updates with invalid mobile' do
      render_views

      it 'displays error about invalid mobile' do
        sign_in(user)
        put :mobile, update_user_mobile_form: { mobile: '123' }

        expect(response.body).to have_content('number is invalid')
      end
    end
  end
end
