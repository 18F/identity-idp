# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Idv::ReproofRequiredPolicy do
  let(:active_profile) { nil }
  let(:service_provider) { nil }

  subject(:policy) do
    described_class.new(active_profile: active_profile, service_provider: service_provider)
  end

  describe '#needs_to_reproof?' do
    context 'when there is no active profile and no service provider' do
      it 'returns false' do
        expect(policy.needs_to_reproof?).to eq false
      end
    end

    context 'reproof forcing SP logic' do
      let(:reproof_forcing_issuer) { 'reproof-forcing-sp' }
      let(:other_issuer) { 'other-sp' }
      let(:service_provider) { create(:service_provider, issuer: reproof_forcing_issuer) }
      let(:initiating_sp) { create(:service_provider, issuer: other_issuer) }
      let(:active_profile) do
        create(
          :profile, :active,
          initiating_service_provider_issuer: initiating_sp.issuer
        )
      end

      before do
        allow(IdentityConfig.store).to receive(:reproof_forcing_service_provider)
          .and_return(reproof_forcing_issuer)
      end

      context 'when current SP is the reproof-forcing SP and initiating SP is different' do
        it 'returns true' do
          expect(policy.needs_to_reproof?).to eq true
        end
      end

      context 'when current SP is not the reproof-forcing SP' do
        let(:service_provider) { initiating_sp }

        it 'returns false' do
          expect(policy.needs_to_reproof?).to eq false
        end
      end

      context 'when current SP is the reproof-forcing SP and initiating SP is the same' do
        let(:active_profile) do
          create(
            :profile, :active,
            initiating_service_provider_issuer: reproof_forcing_issuer
          )
        end

        it 'returns false' do
          expect(policy.needs_to_reproof?).to eq false
        end
      end

      context 'when active profile has no initiating service provider' do
        let(:active_profile) do
          create(:profile, :active, initiating_service_provider_issuer: nil)
        end

        it 'returns true because initiating SP is not the reproof-forcing SP' do
          expect(policy.needs_to_reproof?).to eq true
        end
      end
    end

    context 'non-facial-match reproofing logic' do
      let(:non_fm_issuer) { 'urn:gov:gsa:openidconnect:non-fm-reproof-sp' }
      let(:service_provider) { create(:service_provider, issuer: non_fm_issuer) }

      before do
        allow(IdentityConfig.store).to receive(:reproof_forcing_service_provider)
          .and_return('')
        allow(IdentityConfig.store).to receive(:reproof_non_facial_match_service_providers)
          .and_return(reproof_non_facial_match_service_providers)
      end

      let(:reproof_non_facial_match_service_providers) { [non_fm_issuer] }

      context 'when the SP is not in reproof_non_facial_match_service_providers' do
        let(:reproof_non_facial_match_service_providers) { ['some-other-issuer'] }
        let(:active_profile) { create(:profile, :active, idv_level: :legacy_unsupervised) }

        it 'returns false' do
          expect(policy.needs_to_reproof?).to eq false
        end
      end

      context 'when the SP is in reproof_non_facial_match_service_providers' do
        context 'when active_profile is nil' do
          let(:active_profile) { nil }

          it 'returns false' do
            expect(policy.needs_to_reproof?).to eq false
          end
        end

        context 'when active_profile is unsupervised_with_selfie (opt-in facial match)' do
          let(:active_profile) { create(:profile, :facial_match_proof) }

          it 'returns false' do
            expect(policy.needs_to_reproof?).to eq false
          end
        end

        context 'when active_profile is an in_person profile' do
          let(:active_profile) { create(:profile, :in_person_verified) }

          it 'returns true' do
            expect(policy.needs_to_reproof?).to eq true
          end
        end

        context 'when active_profile is a proofing_agent profile' do
          let(:active_profile) { create(:profile, :active, idv_level: :proofing_agent) }

          it 'returns true' do
            expect(policy.needs_to_reproof?).to eq true
          end
        end
      end
    end
  end
end
