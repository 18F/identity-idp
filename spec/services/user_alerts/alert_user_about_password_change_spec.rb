require 'rails_helper'

describe UserAlerts::AlertUserAboutPasswordChange do
  describe '#call' do
    it 'sends an email to all of the users confirmed email addresses' do
      user = create(:user)
      disavowal_token = 'asdf1234'
      user.email_addresses.destroy_all
      confirmed_email_addresses = create_list(:email_address, 2, user: user)
      create(:email_address, user: user, confirmed_at: nil)

      allow(UserMailer).to receive(:password_changed).and_call_original

      described_class.call(user, disavowal_token)

      expect(UserMailer).to have_received(:password_changed).twice
      expect(UserMailer).to have_received(:password_changed).
        with(confirmed_email_addresses[0], disavowal_token: disavowal_token)
      expect(UserMailer).to have_received(:password_changed).
        with(confirmed_email_addresses[1], disavowal_token: disavowal_token)
    end
  end
end
