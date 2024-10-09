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

  describe '#fed_or_mil_email?' do
    subject(:result) { email_address.fed_or_mil_email? }

    context 'with an email that is in federal_email_domains' do
      let!(:federal_email_domain) { create(:federal_email_domain, name: 'gsa.gov') }
      let(:email) { 'example@gsa.gov' }

      it { expect(result).to eq(true) }
    end

    context 'with an email that has a .mil TLD' do
      let(:email) { 'example@example.mil' }

      it { expect(result).to eq(true) }
    end

    context 'with an email that is neither in federal_email_domains nor has a .mil TLD' do
      let(:email) { 'example@bad.gov' }

      it { expect(result).to eq(false) }
    end
  end

  describe '#mil_email?' do
    subject(:result) { email_address.mil_email? }

    context 'with an email that does not have a .mil TLD' do
      let(:email) { 'example@example.gov' }

      it { expect(result).to eq(false) }
    end

    context 'with an email that has a .mil TLD' do
      let(:email) { 'example@example.mil' }

      it { expect(result).to eq(true) }
    end
  end

  describe 'destruction' do
    let(:user) { create(:user) }
    let(:email) { 'jd@example.com' }
    let(:email_address) { create(:email_address, email: email) }

    it 'removes associated identity email address id' do
      user.identities << ServiceProviderIdentity.create(
        service_provider: 'http://localhost:3000',
        last_authenticated_at: Time.zone.now,
        email_address_id: user.email_addresses.last.id,
      )

      user.email_addresses.last.destroy

      expect(user.identities.last.email_address_id).to be(nil)
    end
  end

  describe '#fed_email?' do
    subject(:result) { email_address.fed_email? }
    let!(:federal_email_domain) { create(:federal_email_domain, name: 'gsa.gov') }

    context 'with an email domain that is not in federal_email_domains' do
      let(:email) { 'example@bad.gov' }

      it { expect(result).to eq(false) }
    end

    context 'with an email domain that is in federal_email_domains' do
      let(:email) { 'example@gsa.gov' }

      it { expect(result).to eq(true) }
    end

    context 'with a bad email address that has no domain' do
      let(:email) { 'email_with_no_domain' }

      it { expect(result).to eq(false) }
    end
  end
end
