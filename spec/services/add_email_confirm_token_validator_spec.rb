require 'rails_helper'

describe AddEmailConfirmTokenValidator do
  describe '#submit' do
    subject { described_class.new(email_address) }

    context 'the email address exists and the token is not expired' do
      let(:email_address) { create(:email_address, confirmation_sent_at: Time.zone.now) }

      it 'returns a successful result' do
        result = subject.submit

        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
        expect(result.extra).to eq(user_id: email_address.user.uuid)
      end
    end

    context 'the email address exists and the token is expired' do
      let(:email_address) { create(:email_address, confirmation_sent_at: 3.days.ago) }

      it 'returns an unsuccessful result' do
        result = subject.submit

        expect(result.success?).to eq(false)
        expect(result.errors).to eq(confirmation_token: [t('errors.messages.expired')])
        expect(result.extra).to eq(user_id: email_address.user.uuid)
      end
    end

    context 'the email address does not exist' do
      let(:email_address) { nil }

      it 'returns an unsuccessful result' do
        result = subject.submit

        expect(result.success?).to eq(false)
        expect(result.errors).to eq(confirmation_token: [t('errors.messages.not_found')])
        expect(result.extra).to eq(user_id: nil)
      end
    end
  end
end
