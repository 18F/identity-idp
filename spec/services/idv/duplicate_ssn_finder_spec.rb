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
        create(:profile, pii: { ssn: ssn })

        expect(subject.ssn_is_unique?).to eq false
      end

      it 'recognizes fingerprint regardless of HMAC key age' do
        create(:profile, pii: { ssn: ssn })
        rotate_hmac_key

        expect(subject.ssn_is_unique?).to eq false
      end
    end

    context 'when ssn is already taken by same profile' do
      it 'is valid' do
        create(:profile, pii: { ssn: ssn }, user: user)

        expect(subject.ssn_is_unique?).to eq true
      end

      it 'recognizes fingerprint regardless of HMAC key age' do
        create(:profile, pii: { ssn: ssn }, user: user)
        rotate_hmac_key

        expect(subject.ssn_is_unique?).to eq true
      end
    end
  end

  describe '#associated_facial_match_profiles_with_ssn' do
    let(:ssn) { '123-45-6789' }
    let(:user) { create(:user) }

    subject { described_class.new(ssn: ssn, user: user) }
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

    subject { described_class.new(ssn: ssn, user: user) }
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
end
