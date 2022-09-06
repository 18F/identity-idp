require 'rails_helper'

RSpec.describe Idv::StepIndicatorConcern, type: :controller do
  controller ApplicationController do
    include Idv::StepIndicatorConcern
  end

  let(:profile) { nil }
  let(:user) { create(:user, profiles: [profile].compact) }

  before { stub_sign_in(user) }

  describe '#step_indicator_steps' do
    subject(:steps) { controller.step_indicator_steps }

    it 'returns doc auth steps' do
      expect(steps).to eq Idv::Flows::DocAuthFlow::STEP_INDICATOR_STEPS
    end

    context 'with pending profile' do
      let(:profile) { create(:profile, deactivation_reason: :gpo_verification_pending) }

      it 'returns doc auth gpo steps' do
        expect(steps).to eq Idv::Flows::DocAuthFlow::STEP_INDICATOR_STEPS_GPO
      end
    end

    context 'with gpo address verification method' do
      before do
        idv_session = instance_double(Idv::Session)
        allow(idv_session).to receive(:method_missing).
          with(:address_verification_mechanism).
          and_return('gpo')
        allow(controller).to receive(:idv_session).and_return(idv_session)
      end

      it 'returns doc auth gpo steps' do
        expect(steps).to eq Idv::Flows::DocAuthFlow::STEP_INDICATOR_STEPS_GPO
      end
    end

    context 'with in person proofing component' do
      context 'with proofing component via pending profile' do
        let(:profile) do
          create(
            :profile,
            deactivation_reason: :gpo_verification_pending,
            proofing_components: { 'document_check' => Idp::Constants::Vendors::USPS },
          )
        end

        it 'returns in person gpo steps' do
          expect(steps).to eq Idv::Flows::InPersonFlow::STEP_INDICATOR_STEPS_GPO
        end
      end

      context 'with proofing component via current idv session' do
        before do
          ProofingComponent.create(user: user, document_check: Idp::Constants::Vendors::USPS)
        end

        it 'returns in person steps' do
          expect(steps).to eq Idv::Flows::InPersonFlow::STEP_INDICATOR_STEPS
        end

        context 'with gpo address verification method' do
          before do
            idv_session = instance_double(Idv::Session)
            allow(idv_session).to receive(:method_missing).
              with(:address_verification_mechanism).
              and_return('gpo')
            allow(controller).to receive(:idv_session).and_return(idv_session)
          end

          it 'returns in person gpo steps' do
            expect(steps).to eq Idv::Flows::InPersonFlow::STEP_INDICATOR_STEPS_GPO
          end
        end
      end
    end
  end
end
