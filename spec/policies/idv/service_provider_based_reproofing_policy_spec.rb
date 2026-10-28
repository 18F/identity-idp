# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Idv::ServiceProviderBasedReproofingPolicy do
  let(:active_profile) { nil }
  let(:service_provider) { nil }

  let(:facial_match) { true }
  let(:resolved_authn_context_result) do
    if service_provider
      double(service_provider: service_provider, facial_match?: facial_match)
    end
  end

  subject(:policy) do
    described_class.new(
      active_profile: active_profile,
      service_provider: service_provider,
      resolved_authn_context_result: resolved_authn_context_result,
    )
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

      context 'when the authn context does not require facial match' do
        let(:facial_match) { false }

        it 'returns false' do
          expect(policy.needs_to_reproof?).to eq false
        end
      end
    end

    context 'unsupervised_with_selfie reproofing logic' do
      let(:non_fm_issuer) { 'urn:gov:gsa:openidconnect:non-fm-reproof-sp' }
      let(:service_provider) { create(:service_provider, issuer: non_fm_issuer) }

      before do
        allow(IdentityConfig.store)
          .to receive(:reproof_forcing_service_provider)
          .and_return('')
        allow(IdentityConfig.store)
          .to receive(:reproof_if_not_unsupervised_with_selfie_service_providers)
          .and_return(reproof_if_not_unsupervised_with_selfie_service_providers)
      end

      let(:reproof_if_not_unsupervised_with_selfie_service_providers) { [non_fm_issuer] }

      context 'when the SP is not in reproof_if_not_unsupervised_with_selfie_service_providers' do
        let(:reproof_if_not_unsupervised_with_selfie_service_providers) { ['some-other-issuer'] }
        let(:active_profile) { create(:profile, :active, idv_level: :legacy_unsupervised) }

        it 'returns false' do
          expect(policy.needs_to_reproof?).to eq false
        end
      end

      context 'when the SP is in reproof_if_not_unsupervised_with_selfie_service_providers' do
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

        context 'when the authn context does not require facial match' do
          let(:facial_match) { false }
          let(:active_profile) { create(:profile, :in_person_verified) }

          it 'returns false' do
            expect(policy.needs_to_reproof?).to eq false
          end
        end
      end
    end
  end

  describe '#reproof_reason' do
    context 'when reproofing is not required' do
      it 'returns nil' do
        expect(policy.reproof_reason).to be_nil
      end
    end

    context 'when reproof_forcing_sp is the cause' do
      let(:reproof_forcing_issuer) { 'reproof-forcing-sp' }
      let(:other_issuer) { 'other-sp' }
      let(:service_provider) { create(:service_provider, issuer: reproof_forcing_issuer) }
      let(:active_profile) do
        create(
          :profile, :active,
          initiating_service_provider_issuer: other_issuer
        )
      end

      before do
        allow(IdentityConfig.store).to receive(:reproof_forcing_service_provider)
          .and_return(reproof_forcing_issuer)
      end

      it 'returns :reproof_forcing_sp' do
        expect(policy.reproof_reason).to eq :reproof_forcing_sp
      end
    end

    context 'when unsupervised_with_selfie reproofing is the cause' do
      let(:non_fm_issuer) { 'urn:gov:gsa:openidconnect:non-fm-reproof-sp' }
      let(:service_provider) { create(:service_provider, issuer: non_fm_issuer) }
      let(:active_profile) { create(:profile, :in_person_verified) }

      before do
        allow(IdentityConfig.store)
          .to receive(:reproof_forcing_service_provider)
          .and_return('')
        allow(IdentityConfig.store)
          .to receive(:reproof_if_not_unsupervised_with_selfie_service_providers)
          .and_return([non_fm_issuer])
      end

      it 'returns :unsupervised_with_selfie_required' do
        expect(policy.reproof_reason).to eq :unsupervised_with_selfie_required
      end
    end
  end
end
