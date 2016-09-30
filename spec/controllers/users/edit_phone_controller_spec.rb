require 'rails_helper'

include Features::MailerHelper
include Features::LocalizationHelper

describe Users::EditPhoneController do
  describe '#phone' do
    let(:user) { create(:user, :signed_up, phone: '+1 (202) 555-1234') }
    let(:second_user) { create(:user, :signed_up, phone: '+1 (202) 555-5678') }
    let(:new_phone) { '555-555-5555' }

    context 'user changes phone' do
      before do
        stub_sign_in(user)

        stub_analytics
        allow(@analytics).to receive(:track_event)

        put :update, update_user_phone_form: { phone: new_phone }
      end

      it 'lets user know they need to confirm their new phone' do
        expect(flash[:notice]).to eq t('devise.registrations.phone_update_needs_confirmation')
        expect(user.reload.phone).to_not eq '+1 (555) 555-5555'
        expect(@analytics).to have_received(:track_event).
          with('User asked to update their phone number')
        expect(response).to render_template('shared/choose_delivery_method')
      end
    end

    context 'user enters an empty phone' do
      render_views

      it 'displays an error message and does not delete the phone' do
        stub_sign_in(user)
        put :update, update_user_phone_form: { phone: '' }

        expect(response.body).to have_content invalid_phone_message
        expect(user.reload.phone).to be_present
      end
    end

    context "user changes phone to another user's phone" do
      before do
        stub_sign_in(user)

        stub_analytics
        allow(@analytics).to receive(:track_event)

        put :update, update_user_phone_form: { phone: second_user.phone }
      end

      it 'processes successfully and informs user' do
        expect(flash[:notice]).to eq t('devise.registrations.phone_update_needs_confirmation')
        expect(user.reload.phone).to_not eq second_user.phone
        expect(@analytics).to have_received(:track_event).
          with('User asked to update their phone number')
        expect(response).to render_template('shared/choose_delivery_method')
      end
    end

    context 'user updates with invalid phone' do
      render_views

      it 'displays error about invalid phone' do
        stub_sign_in(user)
        put :update, update_user_phone_form: { phone: '123' }

        expect(response.body).to have_content('number is invalid')
      end
    end

    context 'user submits the form without changing their phone' do
      it 'redirects to profile page without any messages' do
        stub_sign_in(user)

        put :update, update_user_phone_form: { phone: user.phone }

        expect(response).to redirect_to profile_url
        expect(flash.keys).to be_empty
      end
    end
  end
end
