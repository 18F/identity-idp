require 'rails_helper'

RSpec.describe SuspendedEmail, type: :model do
  describe 'associations' do
    it { should belong_to(:email_address).class_name('EmailAddress') }
  end

  describe 'validations' do
    it { should validate_presence_of(:digested_base_email) }
  end

  describe '.generate_email_digest' do
    it 'generates the correct digest for a given email' do
      email = 'test@example.com'
      expected_digest = Digest::SHA256.hexdigest('test@example.com')

      expect(SuspendedEmail.generate_email_digest(email)).to eq(expected_digest)
    end
  end

  describe '.blocked_email_address' do
    context 'when the email is not blocked' do
      it 'returns nil' do
        email = 'not_blocked@example.com'

        expect(SuspendedEmail.find_with_email(email)).to be_nil
      end
    end

    context 'when the email is blocked' do
      it 'returns the original email address' do
        blocked_email = FactoryBot.create(:email_address, email: 'blocked@example.com')
        digested_base_email = SuspendedEmail.generate_email_digest('blocked@example.com')
        FactoryBot.create(
          :suspended_email,
          digested_base_email: digested_base_email,
          email_address: blocked_email,
        )

        expect(SuspendedEmail.find_with_email('blocked@example.com')).to eq(blocked_email)
      end
    end
  end

  describe '.find_with_email_digest' do
    context 'when the email is not blocked' do
      it 'returns nil' do
        email = 'not_blocked@example.com'
        digested_base_email = Digest::SHA256.hexdigest(email)

        expect(SuspendedEmail.find_with_email_digest(digested_base_email)).to be_nil
      end
    end

    context 'when the email is blocked' do
      it 'returns the original email address' do
        blocked_email = FactoryBot.create(:email_address, email: 'blocked@example.com')
        digested_base_email = Digest::SHA256.hexdigest('blocked@example.com')
        FactoryBot.create(
          :suspended_email,
          digested_base_email: digested_base_email,
          email_address: blocked_email,
        )

        expect(SuspendedEmail.find_with_email_digest(digested_base_email)).to eq(blocked_email)
      end
    end
  end
end
