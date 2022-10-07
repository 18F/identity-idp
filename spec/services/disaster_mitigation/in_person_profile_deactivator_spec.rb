require 'rails_helper'

RSpec.describe DisasterMitigation::InPersonProfileDeactivator do
  describe 'deactivate_profiles' do
    let(:service_provider) { nil }
    let(:other_service_provider) { create(:service_provider) }
    let(:enrollments) do
      enrollments = nil
      freeze_time do
        enrollments = [
          create(
            :in_person_enrollment, :pending, issuer: service_provider&.issuer
          ),
          create(
            :in_person_enrollment, :passed, issuer: service_provider&.issuer
          ),
          create(
            :in_person_enrollment, :pending, issuer: other_service_provider&.issuer
          ),
          create(
            :in_person_enrollment, :passed, issuer: other_service_provider&.issuer
          ),
        ]
      end
      enrollments
    end
    let(:profiles) { enrollments.map(&:profile) }

    context 'when a partner ID is specified' do
      let(:service_provider) { create(:service_provider) }
      let(:issuer) { service_provider.issuer }

      context 'when partner ID is not an integer string' do
        it 'fails'
      end

      context 'when deactivating pending profiles' do
        let(:status_type) { 'pending' }
        let!(:target_profiles) do
          profiles.select do |profile|
            profile.active == false &&
              profile&.in_person_enrollment&.status == 'pending' &&
              profile&.in_person_enrollment&.issuer == issuer
          end
        end

        it 'deactivates pending profiles for the specified partner ID' do
          described_class.deactivate_profiles(false, status_type, issuer)
          target_profiles.each do |profile|
            profile.reload
            expect(profile.deactivation_reason).to eq('in_person_contingency_deactivation')
            expect(profile.in_person_enrollment.status).to eq('cancelled')
          end
        end

        it 'does not deactivate non-pending profiles or profiles for other partners' do
          described_class.deactivate_profiles(false, status_type, issuer)
          untargeted_profiles = profiles - target_profiles
          untargeted_profiles.each do |profile|
            profile.reload
            expect(profile.updated_at).to eq(profile.created_at)
            expect(profile.deactivation_reason).not_to eq('in_person_contingency_deactivation')
            expect(profile.in_person_enrollment.status).not_to eq('cancelled')
          end
        end

        it 'logs stuff'
        it 'catches errors and logs more stuff'
      end
    end
  end

  describe 'reactivate_profiles' do
    context 'when a partner ID is specified' do
      context 'when reactivating pending profiles' do
        it 'reactivates pending profiles for the specified partner ID'
        it 'does not reactivate non-pending profiles'
        it 'does not reactivate profiles for other partners'
        it 'logs stuff'
        it 'catches errors and logs more stuff'
      end
    end
  end
end
