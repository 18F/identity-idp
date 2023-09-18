require 'rails_helper'

RSpec.describe 'MfaSetupConcern' do
  controller ApplicationController do
    include MfaSetupConcern
  end

  let(:user) { create(:user, :fully_registered) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
  end

  describe '#next_setup_path' do
    subject(:next_setup_path) { controller.next_setup_path }

    context 'when user converts from second mfa reminder' do
      let(:user) { create(:user, :fully_registered, :with_phone, :with_backup_code) }

      before do
        stub_sign_in_before_2fa(user)
        stub_analytics
        controller.user_session[:second_mfa_reminder_conversion] = true
        controller.user_session[:mfa_selections] = []
      end

      it 'tracks analytics event' do
        next_setup_path

        expect(@analytics).to have_logged_event(
          'User Registration: MFA Setup Complete',
          success: true,
          mfa_method_counts: { phone: 1, backup_codes: 10 },
          enabled_mfa_methods_count: 2,
          second_mfa_reminder_conversion: true,
          in_account_creation_flow: false,
        )
      end
    end
  end

  describe '#show_skip_additional_mfa_link?' do
    subject(:show_skip_additional_mfa_link?) { controller.show_skip_additional_mfa_link? }

    it 'returns true' do
      expect(show_skip_additional_mfa_link?).to eq(true)
    end

    context 'with only webauthn_platform registered' do
      let(:user) { create(:user, :with_webauthn_platform) }

      before do
        stub_sign_in(user)
      end

      it 'returns false' do
        expect(show_skip_additional_mfa_link?).to eq(false)
      end
    end
  end
end
