require 'rails_helper'

RSpec.describe DisasterMitigation::InPersonProfileDeactivator do
  describe 'deactivate_profiles' do
    let(:issuer) { nil }
    let(:other_issuer) { '8' }
    let(:profiles) do
      [
        create(:profile, :in_person_pending, issuer: issuer),
        create(:profile, :in_person_proofed, issuer: issuer),
        create(:profile, :in_person_pending, issuer: other_issuer),
        create(:profile, :in_person_proofed, issuer: other_issuer),
      ]
    end

    context 'when a partner ID is specified' do
      let(:issuer) { '1' }
      context 'when deactivating pending profiles' do
        let(:status_type) { 'pending' }
        let(:pending_profiles) do
          profiles.select do |profile|
            profile.active == false &&
              profile&.in_person_enrollment&.status == 'pending' &&
              profile&.in_person_enrollment&.issuer == issuer
          end
        end

        it 'deactivates pending profiles for the specified partner ID' do
          described_class.deactivate_profiles(true, status_type, issuer)
          pending_profiles.each do |profile|
            expect(profile.deactivation_reason).to eq('in_person_contingency_deactivation')
            expect(profile.in_person_enrollment.status).to eq('cancelled')
          end
        end

        it 'does not deactivate non-pending profiles'
        it 'does not deactivate profiles for other partners'
      end
    end
  end

  describe 'reactivate_profiles' do
    context 'when a partner ID is specified' do
      context 'when reactivating pending profiles' do
        it 'reactivates pending profiles for the specified partner ID'
        it 'does not reactivate non-pending profiles'
        it 'does not reactivate profiles for other partners'
      end
    end
  end
end
