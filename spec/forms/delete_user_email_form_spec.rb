require 'rails_helper'

describe DeleteUserEmailForm do
  describe '#submit' do
    context 'with only a single email address' do
      let(:user) { create(:user, email: 'test@example.com ') }
      let(:email_address) { user.email_addresses.first }
      let(:form) { described_class.new(user, email_address) }
      let!(:result) { form.submit }

      it 'returns success' do
        expect(result.success?).to eq false
      end

      it 'leaves the last email alone' do
        expect(user.email_addresses.reload).to_not be_empty
      end
    end

    context 'with multiple email addresses' do
      let(:user) { create(:user, :signed_up, :with_multiple_emails) }
      let(:email_address) { user.email_addresses.first }
      let(:form) { described_class.new(user, email_address) }
      let!(:result) { form.submit }

      it 'returns success' do
        expect(result.success?).to eq true
      end

      it 'removes the email' do
        deleted_email = user.email_addresses.reload.where(id: email_address.id)
        expect(deleted_email).to be_empty
      end
    end

    context 'with a email of a different user' do
      let(:user) { create(:user, :signed_up, :with_multiple_emails) }
      let(:other_user) { create(:user, :signed_up, :with_multiple_emails) }
      let(:email_address) { other_user.email_addresses.first }
      let(:form) { described_class.new(user, email_address) }
      let!(:result) { form.submit }

      it 'returns failure' do
        expect(result.success?).to eq false
      end

      it 'leaves the email alone' do
        email = other_user.email_addresses.reload.where(id: email_address.id)
        expect(email).to_not be_empty
      end
    end
  end
end
