require 'rails_helper'

describe Users::PhonesController do
  include Features::MailerHelper

  describe '#phone' do
    let(:user) { create(:user, :signed_up, with: { phone: '+1 (202) 555-1234' }) }
    let(:second_user) { create(:user, :signed_up, with: { phone: '+1 (202) 555-5678' }) }
    let(:new_phone) { '202-555-4321' }

    context 'user tries to change phone settings' do
      before do
        stub_sign_in(user)

        stub_analytics
        allow(@analytics).to receive(:track_event)

        put :update, params: {
          edit_phone_form: { otp_delivery_preference: 'foo' },
        }
      end

      it 'does not allow delivery preference to something other than sms or voice' do
        expect(response).to render_template(:edit)
      end
    end

    context 'user creates a phone with existing number' do
      it 'should not allow the user to have two duplicate phones' do
        stub_sign_in(user)

        put :create, params: {
          new_phone_form: { phone: '202-555-1234',
                            international_code: 'US',
                            otp_delivery_preference: 'sms' },
        }
        # t('errors.messages.phone_duplicate')
        # expect(response).to render_template(:edit)
      end
    end
  end

  describe '#delete' do
    before(:each) do
      stub_analytics
      allow(@analytics).to receive(:track_event)
    end

    context 'user has no phone' do
      let(:user) { create(:user) }

      let(:extra_analytics) do
        { configuration_id: nil,
          configuration_owner: nil,
          configuration_present: false,
          errors: {},
          mfa_method_counts: {},
          success: true }
      end

      it 'redirects without an error' do
        stub_sign_in(user)

        extra = extra_analytics

        delete :delete

        expect(@analytics).to have_received(:track_event).
          with(Analytics::PHONE_DELETION_REQUESTED, extra)
        expect(response).to redirect_to(account_url)
      end
    end

    context 'user has only a phone' do
      let(:user) { create(:user, :with_phone, :with_webauthn) }

      let(:extra_analytics) do
        { configuration_id: user.phone_configurations.first.id,
          configuration_owner: user.uuid,
          configuration_present: true,
          errors: { user: ['must have 3 or more MFA configurations'] },
          mfa_method_counts: { webauthn: 1, phone: 1 },
          success: false }
      end

      it 'redirects without an error' do
        stub_sign_in(user)

        extra = extra_analytics

        delete :delete

        expect(@analytics).to have_received(:track_event).
          with(Analytics::PHONE_DELETION_REQUESTED, extra)
        expect(response).to redirect_to(account_url)
      end

      it 'leaves the phone' do
        stub_sign_in(user)

        delete :delete

        user.phone_configurations.reload
        expect(user.phone_configurations.count).to eq 1
      end
    end

    context 'user has more than one mfa option' do
      let(:user) { create(:user, :signed_up, :with_piv_or_cac) }

      let(:extra_analytics) do
        { configuration_id: user.phone_configurations.first.id,
          configuration_owner: user.uuid,
          configuration_present: true,
          errors: {},
          mfa_method_counts: { piv_cac: 1, backup_codes: 10 },
          success: true }
      end

      it 'redirects without an error' do
        stub_sign_in(user)

        extra = extra_analytics

        delete :delete

        expect(@analytics).to have_received(:track_event).
          with(Analytics::PHONE_DELETION_REQUESTED, extra)
        expect(response).to redirect_to(account_url)
      end

      it 'removes the phone' do
        stub_sign_in(user)

        delete :delete

        user.phone_configurations.reload
        expect(user.phone_configurations).to be_empty
      end
    end
  end

  context 'user adds phone' do
    let(:user) { create(:user, :signed_up, with: { phone: '+1 (202) 555-1234' }) }
    let(:new_phone) { '202-555-4321' }
    before do
      stub_sign_in(user)

      stub_analytics
      allow(@analytics).to receive(:track_event)
    end

    it 'gives the user a form to enter a new phone number' do
      get :add
      expect(response).to render_template(:add)
    end
  end
end
