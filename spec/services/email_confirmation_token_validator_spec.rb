require 'rails_helper'

describe EmailConfirmationTokenValidator do
  describe '#submit' do
    subject { described_class.new(email_address) }

    context 'the email address exists and the token is not expired' do
      let(:email_address) do
        create(:email_address, confirmed_at: nil, confirmation_sent_at: Time.zone.now)
      end

      it 'returns a successful result' do
        result = subject.submit

        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
        expect(subject.email_address_already_confirmed?).to eq(false)
        expect(subject.confirmation_period_expired?).to eq(false)
        expect(result.extra).to eq(user_id: email_address.user.uuid)
      end
    end

    context 'the email address exists and the token is expired' do
      let(:email_address) do
        create(:email_address, confirmed_at: nil, confirmation_sent_at: 3.days.ago)
      end

      it 'returns an unsuccessful result' do
        result = subject.submit

        expect(result.success?).to eq(false)
        expect(result.errors).to eq(confirmation_token: [t('errors.messages.expired')])
        expect(subject.email_address_already_confirmed?).to eq(false)
        expect(subject.confirmation_period_expired?).to eq(true)
        expect(result.extra).to eq(user_id: email_address.user.uuid)
      end
    end

    context 'the email address exists and is already confirmed' do
      let(:email_address) do
        create(:email_address, confirmed_at: 5.hours.ago, confirmation_sent_at: 6.hours.ago)
      end

      it 'returns an unsuccessful result' do
        result = subject.submit

        expect(result.success?).to eq(false)
        expect(result.errors).to eq(confirmation_token: [t('errors.messages.already_confirmed')])
        expect(subject.email_address_already_confirmed?).to eq(true)
        expect(subject.confirmation_period_expired?).to eq(false)
        expect(result.extra).to eq(user_id: email_address.user.uuid)
      end
    end

    context 'the email address does not exist' do
      let(:email_address) { nil }

      it 'returns an unsuccessful result' do
        result = subject.submit

        expect(result.success?).to eq(false)
        expect(result.errors).to eq(confirmation_token: [t('errors.messages.not_found')])
        expect(subject.email_address_already_confirmed?).to eq(false)
        expect(subject.confirmation_period_expired?).to eq(false)
        expect(result.extra).to eq(user_id: nil)
      end
    end
  end

  describe '#email_address_already_confirmed_by_user?' do
    subject { described_class.new(email_address) }

    context 'the email address was confirmed by the user' do
      let(:email_address) do
        create(:email_address, confirmed_at: 1.day.ago, confirmation_sent_at: 2.days.ago)
      end
      let(:user) { email_address.user }

      it { expect(subject.email_address_already_confirmed_by_user?(user)).to eq(true) }
    end

    context 'the email address was confirmed by a different user' do
      let(:email_address) do
        create(:email_address, confirmed_at: 1.day.ago, confirmation_sent_at: 2.days.ago)
      end
      let(:user) { create(:user) }

      it { expect(subject.email_address_already_confirmed_by_user?(user)).to eq(false) }
    end
  end
end
