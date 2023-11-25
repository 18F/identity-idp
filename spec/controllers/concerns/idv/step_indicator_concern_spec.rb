require 'rails_helper'

RSpec.describe Idv::StepIndicatorConcern, type: :controller do
  controller ApplicationController do
    include IdvSession
    include Idv::StepIndicatorConcern
  end

  let(:profile) { nil }
  let(:user) { create(:user, profiles: [profile].compact) }

  before { stub_sign_in(user) }

  describe '#step_indicator_steps' do
    def force_gpo
      idv_session = instance_double(Idv::Session)
      allow(idv_session).to receive(:method_missing).with(:verify_by_mail?).and_return(true)
      allow(controller).to receive(:idv_session).and_return(idv_session)
    end

    subject(:steps) { controller.step_indicator_steps }

    context 'without an in-person proofing component' do
      let(:doc_auth_step_indicator_steps) do
        [
          { name: :getting_started },
          { name: :verify_id },
          { name: :verify_info },
          { name: :verify_phone_or_address },
          { name: :secure_account },
        ]
      end

      let(:doc_auth_step_indicator_steps_gpo) do
        [
          { name: :getting_started },
          { name: :verify_id },
          { name: :verify_info },
          { name: :get_a_letter },
          { name: :secure_account },
        ]
      end

      context 'without a pending profile' do
        it 'returns doc auth steps' do
          expect(steps).to eq doc_auth_step_indicator_steps
        end
      end

      context 'with a pending profile' do
        let(:profile) { create(:profile, gpo_verification_pending_at: 1.day.ago) }

        it 'returns doc auth gpo steps' do
          expect(steps).to eq doc_auth_step_indicator_steps_gpo
        end
      end

      context 'with gpo address verification method' do
        before { force_gpo }

        it 'returns doc auth gpo steps' do
          expect(steps).to eq doc_auth_step_indicator_steps_gpo
        end
      end
    end

    context 'with in person proofing component' do
      let(:in_person_step_indicator_steps) do
        [
          { name: :find_a_post_office },
          { name: :verify_info },
          { name: :verify_phone_or_address },
          { name: :secure_account },
          { name: :go_to_the_post_office },
        ]
      end

      let(:in_person_step_indicator_steps_gpo) do
        [
          { name: :find_a_post_office },
          { name: :verify_info },
          { name: :secure_account },
          { name: :get_a_letter },
          { name: :go_to_the_post_office },
        ]
      end

      context 'via pending profile' do
        let(:profile) do
          create(
            :profile,
            gpo_verification_pending_at: 1.day.ago,
            proofing_components: { 'document_check' => Idp::Constants::Vendors::USPS },
          )
        end

        it 'returns in person gpo steps' do
          ProofingComponent.create(user: user, document_check: Idp::Constants::Vendors::USPS)
          create(:in_person_enrollment, :establishing, user: user)
          expect(steps).to eq in_person_step_indicator_steps_gpo
        end
      end

      context 'via current idv session' do
        before do
          ProofingComponent.create(user: user, document_check: Idp::Constants::Vendors::USPS)
          create(:in_person_enrollment, :establishing, user: user)
        end

        it 'returns in person steps' do
          expect(steps).to eq in_person_step_indicator_steps
        end

        context 'with gpo address verification method' do
          before { force_gpo }

          it 'returns in person gpo steps' do
            expect(steps).to eq in_person_step_indicator_steps_gpo
          end
        end
      end

      context 'when user is not signed in' do
        let(:user) { nil }
        it 'returns doc auth flow steps and does not crash' do
          expect(steps).to eq(Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS)
        end

        context 'when idv_session method is not present' do
          controller ApplicationController do
            include Idv::StepIndicatorConcern
          end
          it 'returns doc auth flow steps and does not crash' do
            expect(steps).to eq(Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS)
          end
        end

        context 'when idv_session is nil' do
          controller ApplicationController do
            include Idv::StepIndicatorConcern
          end

          before do
            allow(controller).to receive(:idv_session).and_return(nil)
          end

          it 'returns doc auth flow steps and does not crash' do
            expect(steps).to eq(Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS)
          end
        end
      end
    end
  end
end
