require 'rails_helper'

RSpec.describe Idv::DuplicateSsnFinder do
  describe '#ssn_is_unique?' do
    let(:ssn) { '123-45-6789' }
    let(:user) { create(:user) }

    subject { Idv::DuplicateSsnFinder.new(ssn: ssn, user: user) }

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
    let(:service_provider) { OidcAuthHelper::OIDC_FACIAL_MATCH_ISSUER }
    let(:other_service_provider) { OidcAuthHelper::OIDC_FACIAL_MATCH_ISSUER }
    let(:ssn) { '123-45-6789' }
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }
    let(:profile) do
      create(
        :profile,
        idv_level: :unsupervised_with_selfie,
        pii: { ssn: ssn },
        user: user,
        active: true,
      )
    end
    let!(:identity) do
      create(
        :service_provider_identity,
        service_provider: service_provider,
        user: user,
      )
    end
    let(:other_profile_idv_level) { :unsupervised_with_selfie }
    let(:other_profile_ssn) { ssn }
    let(:other_profile_active) { true }
    let!(:other_profile) do
      create(
        :profile,
        idv_level: other_profile_idv_level,
        pii: { ssn: other_profile_ssn },
        user: other_user,
        active: other_profile_active,
      )
    end
    let!(:other_identity) do
      create(
        :service_provider_identity,
        service_provider: other_service_provider,
        user: other_user,
      )
    end

    subject { Idv::DuplicateSsnFinder.new(ssn: ssn, user: user) }

    context 'when the other profile is active, has matching SSN and is at facial match IDV level' do
      it 'returns list with matching profile' do
        expect(subject.duplicate_facial_match_profiles(service_provider:).last.id)
          .to eq(other_profile.id)
      end
    end

    context 'when the other profile is not at facial match IDV level' do
      let(:other_profile_idv_level) { :legacy_unsupervised }

      it 'is empty' do
        expect(subject.duplicate_facial_match_profiles(service_provider:)).to be_empty
      end
    end

    context 'when the other profile has a different SSN' do
      let(:other_profile_ssn) { '555-66-7788' }

      it 'is empty' do
        expect(subject.duplicate_facial_match_profiles(service_provider:)).to be_empty
      end
    end

    context 'when the other profile is not active' do
      let(:other_profile_active) { false }

      it 'is empty' do
        expect(subject.duplicate_facial_match_profiles(service_provider:)).to be_empty
      end
    end

    context 'when the other profile has not been active with the service_provider' do
      let(:other_service_provider) { OidcAuthHelper::OIDC_ISSUER }

      it 'is empty' do
        expect(subject.duplicate_facial_match_profiles(service_provider:)).to be_empty
      end
    end
  end
end
