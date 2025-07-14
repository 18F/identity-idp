require 'rails_helper'

RSpec.describe Idv::DuplicateSsnFinder do
  describe '#ssn_is_unique?' do
    let(:ssn) { '123-45-6789' }
    let(:user) { create(:user) }
    let(:sp) { 'urn:gov:gsa:openidconnect:inactive:sp:test' }

    subject { described_class.new(ssn: ssn, user: user, issuer: sp) }

    before do
      allow(IdentityConfig.store).to receive(:eligible_one_account_providers)
        .and_return([OidcAuthHelper::OIDC_FACIAL_MATCH_ISSUER])
    end

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

  describe '#associated_facial_match_profiles_with_ssn' do
    let(:ssn) { '123-45-6789' }
    let(:user) { create(:user) }
    let(:sp) { 'urn:gov:gsa:openidconnect:inactive:sp:test' }

    subject { described_class.new(ssn: ssn, user: user, issuer: sp) }

    before do
      allow(IdentityConfig.store).to receive(:eligible_one_account_providers)
        .and_return([OidcAuthHelper::OIDC_FACIAL_MATCH_ISSUER])
    end

    context 'when profile is IAL2' do
      context 'when ssn is taken by different profile by and is IAL2' do
        it 'returns list different profile' do
          create(:profile, :facial_match_proof, pii: { ssn: ssn }, user: user, active: true)

          create(:profile, :facial_match_proof, pii: { ssn: ssn }, active: true)
          expect(subject.associated_facial_match_profiles_with_ssn.size).to eq(1)
        end
      end

      context 'when ssn is taken by different profile by and is not IAL2' do
        it 'returns empty array' do
          create(:profile, :facial_match_proof, pii: { ssn: ssn }, user: user, active: true)

          create(:profile, pii: { ssn: ssn }, active: true)
          expect(subject.associated_facial_match_profiles_with_ssn.size).to eq(0)
        end
      end

      context 'when ssn is not taken by other profiles' do
        it 'returns empty array' do
          create(:profile, :facial_match_proof, pii: { ssn: ssn }, user: user, active: true)
          expect(subject.associated_facial_match_profiles_with_ssn.size).to eq(0)
        end
      end
    end
  end

  describe '#ial2_profile_ssn_is_unique?' do
    let(:ssn) { '123-45-6789' }
    let(:user) { create(:user) }
    let(:sp) { 'urn:gov:gsa:openidconnect:inactive:sp:test' }

    subject { described_class.new(ssn: ssn, user: user, issuer: sp) }

    before do
      allow(IdentityConfig.store).to receive(:eligible_one_account_providers)
        .and_return([OidcAuthHelper::OIDC_FACIAL_MATCH_ISSUER])
    end
    context 'when profile is IAL2' do
      context 'when ssn is taken by different profile by and is IAL2' do
        it 'returns false' do
          create(:profile, :facial_match_proof, pii: { ssn: ssn }, user: user, active: true)

          create(:profile, :facial_match_proof, pii: { ssn: ssn }, active: true)
          expect(subject.ial2_profile_ssn_is_unique?).to eq false
        end
      end

      context 'when ssn is taken by different profile by and is not IAL2' do
        it 'returns true' do
          create(:profile, :facial_match_proof, pii: { ssn: ssn }, user: user, active: true)

          create(:profile, pii: { ssn: ssn }, active: true)
          expect(subject.ial2_profile_ssn_is_unique?).to eq true
        end
      end

      context 'when ssn is not taken by other profiles' do
        it 'returns true' do
          create(:profile, :facial_match_proof, pii: { ssn: ssn }, user: user, active: true)
          expect(subject.ial2_profile_ssn_is_unique?).to eq true
        end
      end
    end
  end

  describe '#associated_facial_match_profiles_with_ssn' do
    let(:ssn) { '123-45-6789' }
    let(:user) { create(:user) }
    let(:user2) { create(:user) }
    let(:sp) { 'urn:gov:gsa:openidconnect:inactive:sp:test' }

    subject { described_class.new(ssn: ssn, user: user, issuer: sp) }

    before do
      allow(IdentityConfig.store).to receive(:eligible_one_account_providers)
        .and_return([
                      'urn:gov:gsa:openidconnect:inactive:sp:test',
                      'urn:gov:gsa:openidconnect:inactive:sp:test2',
                    ])
    end
    context 'when ssn belongs to another profile with the same sp' do
      it 'returns matching profile id' do
        create(:profile, :facial_match_proof, id: 1, pii: { ssn: ssn }, user: user, active: true)

        create(:profile, :facial_match_proof, id: 2, pii: { ssn: ssn }, user: user2, active: true)
        expect(subject.associated_facial_match_profiles_with_ssn.last.id).to eq(2)
      end
    end

    context 'when ssn belongs to another profile with a different sp' do
      it 'does not return matching profile' do
        sp2 = 'urn:gov:gsa:openidconnect:inactive:sp:test2'
        create(:profile, :facial_match_proof, id: 1, pii: { ssn: ssn }, user: user, active: true)

        create(
          :profile,
          :facial_match_proof,
          id: 2,
          pii: { ssn: ssn },
          user: user2,
          active: true,
          initiating_service_provider_issuer: sp2,
        )
        expect(subject.associated_facial_match_profiles_with_ssn.last).to eq(nil)
      end
    end

    context 'when ssn belongs to same provider but sp has not opted in' do
      before do
        allow(IdentityConfig.store).to receive(:eligible_one_account_providers)
          .and_return([])
      end

      it 'does not return matching profile' do
        create(:profile, :facial_match_proof, id: 1, pii: { ssn: ssn }, user: user, active: true)
        create(:profile, :facial_match_proof, id: 2, pii: { ssn: ssn }, user: user2, active: true)
        expect(subject.associated_facial_match_profiles_with_ssn.last).to eq(nil)
      end
    end
  end
end
