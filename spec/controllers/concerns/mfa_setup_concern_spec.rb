require 'rails_helper'

RSpec.describe MfaSetupConcern do
  controller ApplicationController do
    include MfaSetupConcern
  end

  let(:user) { create(:user, :fully_registered) }

  before do
    stub_sign_in(user)
  end

  describe '#next_setup_path' do
    subject(:next_setup_path) { controller.next_setup_path }

    context 'when user has remaining selections to setup' do
      before do
        controller.user_session[:mfa_selections] = ['phone', 'backup_code']
      end

      it 'returns setup path for next method' do
        expect(next_setup_path).to eq(backup_code_setup_url)
      end
    end

    context 'when user has no remaining selections to setup' do
      before do
        controller.user_session[:mfa_selections] = ['phone']
      end

      context 'when user is recommended for webauthn platform for sms user' do
        let(:recommend_webauthn_platform_for_sms_user) { true }

        it 'returns webauthn platform recommended path' do
          expect(next_setup_path).to eq(webauthn_platform_recommended_path)
        end
      end

      context 'when user only set up a single mfa method' do
        it 'returns second mfa recommended path' do
          expect(next_setup_path).to eq(auth_method_confirmation_path)
        end

        context 'when user was already recommended for webauthn platform' do
          let(:user) do
            create(
              :user,
              :fully_registered,
              webauthn_platform_recommended_dismissed_at: 2.minutes.ago,
            )
          end

          it 'returns signup completed path' do
            expect(next_setup_path).to eq(sign_up_completed_path)
          end
        end
      end

      context 'when user set up multiple mfa methods' do
        let(:user) { create(:user, :fully_registered, :with_phone, :with_backup_code) }

        it 'returns signup completed path' do
          expect(next_setup_path).to eq(sign_up_completed_path)
        end
      end
    end

    context 'when user converts from second mfa reminder' do
      let(:user) { create(:user, :fully_registered, :with_phone, :with_backup_code) }

      before do
        stub_analytics
        controller.user_session[:second_mfa_reminder_conversion] = true
        controller.user_session[:mfa_selections] = []
      end

      it 'tracks analytics event' do
        next_setup_path

        expect(@analytics).to have_logged_event(
          'User Registration: MFA Setup Complete',
          success: true,
          mfa_method_counts: { phone: 1, backup_codes: BackupCodeGenerator::NUMBER_OF_CODES },
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
