require 'rails_helper'

RSpec.describe BackupCodeReminderConcern do
  let(:user) { create(:user, :fully_registered) }

  controller ApplicationController do
    include BackupCodeReminderConcern
  end

  before do
    stub_sign_in(user)
  end

  describe '#user_needs_backup_code_reminder?' do
    subject(:user_needs_backup_code_reminder?) { controller.user_needs_backup_code_reminder? }

    context 'if user has dismissed reminder in current session' do
      before do
        controller.user_session[:dismissed_backup_code_reminder] = true
      end

      it { is_expected.to eq(false) }
    end

    context 'if the user does not have backup codes' do
      let(:user) { create(:user, :fully_registered, :with_phone) }

      it { is_expected.to eq(false) }
    end

    context 'if the user has backup codes' do
      context 'if the user account is less than 5 months old' do
        let(:user) do
          create(:user, :fully_registered, :with_phone, :with_backup_code, created_at: 1.day.ago)
        end

        before do
          create(:event, user:, event_type: :sign_in_after_2fa, created_at: 1.minute.ago)
        end

        it { is_expected.to eq(false) }
      end

      context 'if the user account is more than 5 months old' do
        let(:user) do
          create(:user, :fully_registered, :with_phone, :with_backup_code, created_at: 7.months.ago)
        end

        context 'if the user has signed in more recently than 5 months ago' do
          before do
            create(:event, user:, event_type: :sign_in_after_2fa, created_at: 4.months.ago)
            create(:event, user:, event_type: :sign_in_after_2fa, created_at: 1.minute.ago)
          end

          it { is_expected.to eq(false) }
        end

        context 'if the user not signed in within the past 5 months' do
          before do
            create(:event, user:, event_type: :sign_in_after_2fa, created_at: 6.months.ago)
            create(:event, user:, event_type: :sign_in_after_2fa, created_at: 1.minute.ago)
          end

          it { is_expected.to eq(true) }

          context 'if the user authenticated with backup codes' do
            before do
              controller.auth_methods_session.authenticate!(
                TwoFactorAuthenticatable::AuthMethod::BACKUP_CODE,
              )
            end

            it { is_expected.to eq(false) }
          end

          context 'if the user authenticated with remember device' do
            before do
              controller.auth_methods_session.authenticate!(
                TwoFactorAuthenticatable::AuthMethod::REMEMBER_DEVICE,
              )
            end

            it { is_expected.to eq(false) }
          end
        end

        context 'if the user is fully authenticating for the first time' do
          before do
            create(:event, user:, event_type: :sign_in_after_2fa, created_at: 1.minute.ago)
          end

          it { is_expected.to eq(true) }

          context 'if the user authenticated with backup codes' do
            before do
              controller.auth_methods_session.authenticate!(
                TwoFactorAuthenticatable::AuthMethod::BACKUP_CODE,
              )
            end

            it { is_expected.to eq(false) }
          end
        end
      end
    end
  end
end
