require 'rails_helper'

RSpec.describe EmailAddress do
  describe 'Associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to validate_presence_of(:encrypted_email) }
    it { is_expected.to validate_presence_of(:email_fingerprint) }
  end

  let(:email) { 'jd@example.com' }
  let(:email_address) { create(:email_address, email: email) }
  let(:valid_for_hours) { IdentityConfig.store.add_email_link_valid_for_hours.hours }

  describe '.find_with_email' do
    it 'finds by email' do
      create(:email_address, email: email)

      expect(EmailAddress.find_with_email(email)).to be

      expect(EmailAddress.find_with_email('does-not-exist@example.com')).to be_nil
    end

    context 'when email is fingerprinted with an old key' do
      before do
        create(
          :email_address,
          email: email,
          email_fingerprint: Pii::Fingerprinter.previous_fingerprints(email).first,
        )
      end

      it 'looks up by older fingerprints too' do
        expect(EmailAddress.find_with_email(email)).to be
      end
    end

    describe '.update_last_sign_in_at_on_user_id_and_email' do
      let(:user) { create(:user) }
      it 'updates attributes and can look up by previous fingerprints' do
        record = create(
          :email_address,
          email: email,
          user_id: user.id,
          email_fingerprint: Pii::Fingerprinter.previous_fingerprints(email).first,
        )

        expect do
          EmailAddress.update_last_sign_in_at_on_user_id_and_email(user_id: user.id, email: email)
        end.to(change { record.reload.last_sign_in_at })
      end
    end
  end

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

  describe '#confirmation_period_expired?' do
    it 'returns false when within add_email_link_valid_for_hours value' do
      email_address = create(:email_address, confirmation_sent_at: nil)
      email_address.confirmation_sent_at = Time.zone.now - valid_for_hours + 1.minute
      email_address.save
      expect(email_address.confirmation_period_expired?).to be_falsey
      IdentityConfig.store.add_email_link_valid_for_hours.hours
    end

    it 'returns true when beyond add_email_link_valid_for_hours value' do
      email_address = create(:email_address, confirmation_sent_at: nil)
      email_address.confirmation_sent_at = Time.zone.now - valid_for_hours - 1.minute
      email_address.save
      expect(email_address.confirmation_period_expired?).to be_truthy
    end
  end

  describe '#is_fed_or_mil_email?' do
    subject(:result) { email_address.is_fed_or_mil_email? }

    context 'with an email domain that is a fed email' do
      before do
        allow(IdentityConfig.store).to receive(:use_fed_domain_file).and_return(false)
      end
      let(:email) { 'example@example.gov' }

      it { expect(result).to eq(true) }
    end

    context 'with an email that is a mil email' do
      let(:email) { 'example@example.mil' }

      it { expect(result).to be_truthy }
    end

    context 'with an email that is not a mil or fed email' do
      before do
        allow(IdentityConfig.store).to receive(:use_fed_domain_file).and_return(true)
      end

      let(:email) { 'example@bad.gov' }

      it { expect(result).to be_falsey }
    end

    context 'with a non fed email while use_fed_domain_file set to true' do
      before do
        allow(IdentityConfig.store).to receive(:use_fed_domain_file).and_return(true)
      end
      let(:email) { 'example@good.gov' }

      it { expect(result).to be_falsey }
    end
  end

  describe '#is_mil_email?' do
    subject(:result) { email_address.is_mil_email? }

    context 'with an email domain not a mil email' do
      let(:email) { 'example@example.gov' }

      it { expect(result).to be_falsey }
    end

    context 'with an email domain ending in a mil domain email' do
      let(:email) { 'example@example.mil' }

      it { expect(result).to be_truthy }
    end
  end

  describe '#is_fed_email?' do
    subject(:result) { email_address.is_fed_email? }

    context 'use_domain file set to true' do
      before do
        allow(IdentityConfig.store).to receive(:use_fed_domain_file).and_return(true)
      end

      context 'with an email domain not a fed email' do
        let(:email) { 'example@bad.gov' }

        it { expect(result).to be_falsey }
      end

      context 'with an email domain ending in a fed domain email' do
        let(:email) { 'example@gsa.gov' }

        it { expect(result).to be_truthy }
      end
    end
  end
end
