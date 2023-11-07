require 'rails_helper'

RSpec.describe ResetUserPassword do
  subject(:reset_user_password) do
    ResetUserPassword.new(user:, remember_device_revoked_at: now)
  end
  let(:user) { create(:user, :with_multiple_emails, encrypted_password_digest: 30.days.from_now) }
  let(:now) { Time.zone.now }

  describe '#call' do
    subject(:call) { reset_user_password.call }

    it 'changes the password' do
      expect { call }.to(change { user.reload.encrypted_password_digest })
    end

    it 'creates a password_invalidated user event' do
      expect { call }.
        to(change { user.events.password_invalidated.size }.from(0).to(1))
    end

    it 'notifies the user via email to each of their email addresses' do
      expect { call }.
        to(change { ActionMailer::Base.deliveries.count }.by(2))

      mails = ActionMailer::Base.deliveries.last(2)
      expect(mails.map(&:to).flatten).to match_array(user.email_addresses.map(&:email))
    end

    it 'clears all remembered browsers by updating the remember_device_revoked_at timestamp' do
      expect { call }.
        to(change { user.reload.remember_device_revoked_at.to_i }.to(now.to_i))
    end
  end
end
