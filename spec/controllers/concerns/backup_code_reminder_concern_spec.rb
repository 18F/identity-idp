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
      let(:user) { create(:user, :fully_registered, :with_phone, :with_backup_code) }

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
      end
    end
  end
end
