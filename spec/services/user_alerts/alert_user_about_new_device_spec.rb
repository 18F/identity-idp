require 'rails_helper'

describe UserAlerts::AlertUserAboutNewDevice do
  describe '#call' do
    let(:user) { create(:user, :signed_up) }
    let(:disavowal_token) { 'the_disavowal_token' }
    let(:device) { create(:device, user: user) }

    it 'sends an email to all confirmed email addresses' do
      user.email_addresses.destroy_all
      confirmed_email_addresses = create_list(:email_address, 2, user: user)
      create(:email_address, user: user, confirmed_at: nil)

      allow(UserMailer).to receive(:new_device_sign_in).and_call_original

      described_class.call(user, device, disavowal_token)

      expect(UserMailer).to have_received(:new_device_sign_in).twice
      expect(UserMailer).to have_received(:new_device_sign_in).
        with(confirmed_email_addresses[0],
             instance_of(String),
             instance_of(String),
             disavowal_token)
      expect(UserMailer).to have_received(:new_device_sign_in).
        with(confirmed_email_addresses[1],
             instance_of(String),
             instance_of(String),
             disavowal_token)
    end
  end
end
