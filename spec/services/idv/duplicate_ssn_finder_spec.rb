require 'rails_helper'

RSpec.describe Idv::DuplicateSsnFinder do
  describe '#ssn_is_unique?' do
    let(:ssn) { '123-45-6789' }
    let(:user) { create(:user) }

    subject { described_class.new(ssn: ssn, user: user) }

    context 'when the ssn is unique' do
      it { expect(subject.ssn_is_unique?).to eq(true) }
    end

    context 'when ssn is already taken by another profile' do
      it 'returns false' do
        create(:profile, :facial_match_proof, pii: { ssn: ssn })

        expect(subject.ssn_is_unique?).to eq false
      end

      it 'recognizes fingerprint regardless of HMAC key age' do
        create(:profile, :facial_match_proof, pii: { ssn: ssn })
        rotate_hmac_key

        expect(subject.ssn_is_unique?).to eq false
      end

      it 'recognizes fingerprint without dashes' do
        ssn_without_dashes = '123456789'
        create(:profile, :facial_match_proof, pii: { ssn: ssn_without_dashes })

        expect(subject.ssn_is_unique?).to eq false
      end

      it 'recognizes fingerprint when SSN has only the first dash' do
        ssn_with_first_dash = '123-456789'
        create(:profile, :facial_match_proof, pii: { ssn: ssn_with_first_dash })

        expect(subject.ssn_is_unique?).to eq false
      end

      it 'recognizes fingerprint when SSN has only the second dash' do
        ssn_with_second_dash = '12345-6789'
        create(:profile, :facial_match_proof, pii: { ssn: ssn_with_second_dash })

        expect(subject.ssn_is_unique?).to eq false
      end
    end

    context 'when ssn is already taken by same profile' do
      it 'is valid' do
        create(:profile, :facial_match_proof, pii: { ssn: ssn }, user: user)

        expect(subject.ssn_is_unique?).to eq true
      end

      it 'recognizes fingerprint regardless of HMAC key age' do
        create(:profile, :facial_match_proof, pii: { ssn: ssn }, user: user)
        rotate_hmac_key

        expect(subject.ssn_is_unique?).to eq true
      end
    end
  end

  describe '#duplicate_facial_match_profiles' do
    let(:ssn) { '123-45-6789' }
    let(:user) { create(:user) }

    subject { described_class.new(ssn: ssn, user: user) }

    before do
      allow(IdentityConfig.store).to receive(:eligible_one_account_providers)
        .and_return([OidcAuthHelper::OIDC_FACIAL_MATCH_ISSUER])
      create(:profile, :facial_match_proof, pii: { ssn: ssn }, user: user, active: true)
    end

    context 'when the other profile with the same SSN is at facial match IDV level' do
      it 'returns list with matching profile' do
        dup_profile = create(:profile, :facial_match_proof, pii: { ssn: ssn }, active: true)
        expect(subject.duplicate_facial_match_profiles.last.id).to eq(dup_profile.id)
      end
    end

    context 'when the other profile with the same SSN is not at facial match IDV level' do
      it 'is empty' do
        create(:profile, idv_level: :legacy_unsupervised, pii: { ssn: ssn }, active: true)
        expect(subject.duplicate_facial_match_profiles).to be_empty
      end
    end

    context 'when the other profile has a different SSN and is at facial match IDV level' do
      it 'is empty' do
        create(:profile, :facial_match_proof, pii: { ssn: '222-45-6789' }, active: true)
        expect(subject.duplicate_facial_match_profiles).to be_empty
      end
    end
  end
end
