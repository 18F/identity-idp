require 'rails_helper'

describe EmailAddress do
  describe 'Associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_presence_of(:encrypted_email) }
    it { is_expected.to validate_presence_of(:email_fingerprint) }
  end

  let(:email) { 'jd@example.com' }

  let(:email_address) { create(:email_address, email: email) }

  describe 'creation' do
    it 'stores an encrypted form of the email address' do
      expect(email_address.encrypted_email).to_not be_blank
    end
  end

  describe 'encrypted attributes' do
    it 'decrypts email' do
      expect(email_address.email).to eq email
    end

    context 'with unnormalized email' do
      let(:email) { '  jD@Example.Com ' }
      let(:normalized_email) { 'jd@example.com' }

      it 'normalizes email' do
        expect(email_address.email).to eq normalized_email
      end
    end
  end

  describe 'deleting an email address' do
    it 'does not delete the users last email address' do
      user = create(:user, :with_email, email: 'test@example.com ')
      email_address = user.email_addresses.first
      expect { email_address.destroy! }.
        to raise_error('cannot delete last email address')
    end

    it 'deletes when multiple email addresses exist for user' do
      user = create(:user, :signed_up, :with_multiple_emails)
      email_address = user.email_addresses.first
      email_address.destroy!
      deleted_email = user.email_addresses.reload.where(id: email_address.id)
      expect(deleted_email).to be_empty
    end
  end
end
