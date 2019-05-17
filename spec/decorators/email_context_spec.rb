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
end
