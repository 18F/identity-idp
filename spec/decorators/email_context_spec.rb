require 'rails_helper'

describe EmailContext do
  let(:user) { create(:user, :signed_up) }

  subject { described_class.new(user) }

  describe '#last_sign_in_email_address' do
    it 'returns the email with the most recent last_sign_in_at date' do
      last_sign_in_email_address = create(:email_address, user: user, last_sign_in_at: 1.day.ago)
      create(:email_address, user: user, last_sign_in_at: 2.days.ago)

      expect(subject.last_sign_in_email_address).to eq(last_sign_in_email_address)
    end

    it 'does not return an email with a null last_sign_in_at date' do
      last_sign_in_email_address = create(:email_address, user: user, last_sign_in_at: 1.day.ago)
      create(:email_address, user: user, last_sign_in_at: nil)

      expect(subject.last_sign_in_email_address).to eq(last_sign_in_email_address)
    end
  end

  describe '#all_emails_addresse' do
    it 'returns all of a users emails except the last sign in email' do
      last_sign_in_email_address = create(:email_address, user: user, last_sign_in_at: 1.day.ago)
      other_sign_in_email = create(:email_address, user: user, last_sign_in_at: 2.days.ago)
      never_sign_in_email = create(:email_address, user: user, last_sign_in_at: nil)

      email_addresses = subject.all_email_addresses

      expect(email_addresses).to_not include(last_sign_in_email_address)
      expect(email_addresses).to include(other_sign_in_email)
      expect(email_addresses).to include(never_sign_in_email)
    end

    it 'returns an empty array if the user only has one email' do
      last_sign_in_email_address = user.email_addresses.first
      last_sign_in_email_address.update!(last_sign_in_at: 1.day.ago)

      expect(subject.all_email_addresses).to eq([])
    end
  end
end
