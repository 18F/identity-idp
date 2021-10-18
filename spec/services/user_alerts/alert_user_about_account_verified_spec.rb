require 'rails_helper'

describe UserAlerts::AlertUserAboutAccountVerified do
  describe '#call' do
    let(:user) { create(:user, :signed_up) }
    let(:disavowal_token) { 'the_disavowal_token' }
    let(:device) { create(:device, user: user) }
    let(:date_time) { Time.zone.now }

    it 'sends an email to all confirmed email addresses' do
      create_list(:email_address, 2, user: user)
      create(:email_address, user: user, confirmed_at: nil)
      confirmed_email_addresses = user.confirmed_email_addresses

      allow(UserMailer).to receive(:account_verified).and_call_original

      described_class.call(
        user: user,
        date_time: date_time,
        sp_name: '',
        disavowal_token: disavowal_token,
      )

      expect(UserMailer).to have_received(:account_verified).
        exactly(confirmed_email_addresses.count).times

      confirmed_email_addresses.each do |email|
        expect(UserMailer).to have_received(:account_verified).
          with(user,
               email,
               date_time: date_time,
               sp_name: '',
               disavowal_token: disavowal_token)
      end
    end
  end
end
