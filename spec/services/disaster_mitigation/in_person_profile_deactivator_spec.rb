require 'rails_helper'

RSpec.describe DisasterMitigation::InPersonProfileDeactivator do
  describe 'deactivate_pending_profiles' do
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

    context 'when no issuer is specified'

    context 'when an issuer is specified' do
      let(:service_provider) { create(:service_provider) }
      let(:issuer) { service_provider.issuer }

      context 'when issuer is not an integer string' do
        it 'fails'
      end

      let!(:target_profiles) do
        profiles.select do |profile|
          profile.active == false &&
            profile&.in_person_enrollment&.status == 'pending' &&
            profile&.in_person_enrollment&.issuer == issuer
        end
      end

      it 'deactivates pending profiles for the specified issuer' do
        described_class.deactivate_pending_profiles(issuer, false)
        target_profiles.each do |profile|
          profile.reload
          expect(profile.deactivation_reason).to eq('in_person_verification_deactivated')
          expect(profile.in_person_enrollment.status).to eq('cancelled')
        end
      end

      it 'does not deactivate non-pending profiles or profiles for other issuers' do
        described_class.deactivate_pending_profiles(issuer, false)
        untargeted_profiles = profiles - target_profiles
        untargeted_profiles.each do |profile|
          profile.reload
          expect(profile.updated_at).to eq(profile.created_at)
          expect(profile.deactivation_reason).not_to eq('in_person_verification_deactivated')
          expect(profile.in_person_enrollment.status).not_to eq('cancelled')
        end
      end

      it 'logs stuff'
      it 'catches errors and logs more stuff'
    end
  end

  describe 'reactivate_pending_profiles' do
    context 'when no issuer is specified'
    context 'when an issuer is specified' do
      it 'reactivates pending profiles for the specified issuer'
      it 'does not reactivate non-pending profiles'
      it 'does not reactivate profiles for other issuers'
      it 'logs stuff'
      it 'catches errors and logs more stuff'
    end
  end
end
