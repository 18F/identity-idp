require 'rails_helper'

describe DeleteUserEmailForm do
  describe '#submit' do
    subject(:submit) { form.submit }

    context 'with only a single email address' do
      let(:user) { create(:user, email: 'test@example.com ') }
      let(:email_address) { user.email_addresses.first }
      let(:form) { described_class.new(user, email_address) }

      it 'returns failure' do
        result = submit
        expect(result.success?).to eq false
      end

      it 'leaves the last email alone' do
        submit
        expect(user.email_addresses.reload).to_not be_empty
      end

      it 'does not notify subscribers that the identifier was recycled or email changed' do
        expect(PushNotification::HttpPush).to_not receive(:deliver)

        submit
      end
    end

    context 'with multiple email addresses' do
      let(:user) { create(:user, :signed_up, :with_multiple_emails) }
      let(:email_address) { user.email_addresses.first }
      let(:form) { described_class.new(user, email_address) }

      it 'returns success' do
        result = submit
        expect(result.success?).to eq true
      end

      it 'removes the email' do
        submit
        deleted_email = user.email_addresses.reload.where(id: email_address.id)
        expect(deleted_email).to be_empty
      end

      it 'notifies subscribers that the identifier was recycled and the email changed' do
        expect(PushNotification::HttpPush).to receive(:deliver).once.
          with(PushNotification::IdentifierRecycledEvent.new(
            user: user,
            email: email_address.email,
          )).ordered
        expect(PushNotification::HttpPush).to receive(:deliver).once.
          with(PushNotification::EmailChangedEvent.new(
            user: user,
            email: email_address.email,
          )).ordered
        expect(PushNotification::HttpPush).to receive(:deliver).once.
          with(PushNotification::RecoveryInformationChangedEvent.new(
            user: user,
          )).ordered

        submit
      end
    end

    context 'with a email of a different user' do
      let(:user) { create(:user, :signed_up, :with_multiple_emails) }
      let(:other_user) { create(:user, :signed_up, :with_multiple_emails) }
      let(:email_address) { other_user.email_addresses.first }
      let(:form) { described_class.new(user, email_address) }

      it 'returns failure' do
        result = submit
        expect(result.success?).to eq false
      end

      it 'leaves the email alone' do
        submit
        email = other_user.email_addresses.reload.where(id: email_address.id)
        expect(email).to_not be_empty
      end

      it 'does not subscribers that the identier was recycled' do
        expect(PushNotification::HttpPush).to_not receive(:deliver)

        submit
      end
    end
  end
end
