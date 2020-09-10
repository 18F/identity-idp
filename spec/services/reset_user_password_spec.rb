require 'rails_helper'

RSpec.describe ResetUserPassword do
  subject(:reset_user_password) { ResetUserPassword.new(user: user) }
  let(:user) { create(:user, :with_multiple_emails) }

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
  end
end
