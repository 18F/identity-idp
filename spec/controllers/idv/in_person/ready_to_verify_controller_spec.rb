require 'rails_helper'

RSpec.describe Idv::InPerson::ReadyToVerifyController do
  let(:user) { create(:user) }
  let(:in_person_proofing_enabled) { false }
  let(:in_person_proofing_enforce_tmx) { false }
  let(:sp_session) { }

  before do
    stub_analytics
    stub_sign_in(user)
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
      and_return(in_person_proofing_enabled)
    allow(IdentityConfig.store).to receive(:in_person_proofing_enforce_tmx).
      and_return(in_person_proofing_enforce_tmx)
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before, :confirm_two_factor_authenticated,
        :handle_fraud
      )
    end
  end

  describe '#show' do
    subject(:response) { get :show }

    it 'renders not found' do
      expect(response.status).to eq 404
    end

    context 'with in person proofing enabled' do
      let(:in_person_proofing_enabled) { true }

      it 'redirects to account page' do
        expect(response).to redirect_to account_url
      end

      context 'with enrollment' do
        let(:user) { create(:user, :with_pending_in_person_enrollment) }
        let(:profile) { create(:profile, :with_pii, user: user) }

        context 'Evaluates if In-person Proofing is enhanced (EIPP)' do
          context 'when there is no sp_session' do
            let(:eipp_sp_session) { { } }

            before do
              allow(controller).to receive(:sp_session).and_return(eipp_sp_session)
            end

            it 'is not EIPP' do
              response

              # TO DO: ASSIGNS IS DEPRECATED
              expect(assigns(:is_eipp)).to be false
            end
          end

          context 'when vtr (vector of trust) does not include Enhanced Proofing (Pe)' do
            let(:vector_of_trust) { ['C1.P1.Pb'] }
            let(:vtr) { ['C1.P1.Pb'] }
            let(:eipp_sp_session) { { 'vtr' => vtr, 'acr_values' => nil } }

            before do
              allow(controller).to receive(:sp_session).and_return(eipp_sp_session)
            end

            it 'is not EIPP' do
              response

              expect(assigns(:is_eipp)).to be false
            end
          end

          context 'when vtr (vector of trust) includes Enhanced Proofing (Pe)' do
            let(:vector_of_trust) { ['C1.P1.Pe'] }
            let(:vtr) { ['C1.P1.Pe'] }
            let(:eipp_sp_session) { { 'vtr' => vtr, 'acr_values' => nil } }

            before do
              allow(controller).to receive(:sp_session).and_return(eipp_sp_session)
            end

            it 'is EIPP' do
              response

              expect(assigns(:is_eipp)).to be true
            end
          end
        end

        it 'renders show template' do
          expect(response).to render_template :show
        end

        it 'logs analytics' do
          response

          expect(@analytics).to have_logged_event('IdV: in person ready to verify visited')
        end

        context 'with in_person_proofing_enforce_tmx disabled and pending fraud review' do
          let!(:profile) { create(:profile, fraud_review_pending_at: 1.day.ago, user: user) }
          let!(:enrollment) { create(:in_person_enrollment, :passed, user: user, profile: profile) }
          it 'redirects to please call page' do
            response

            expect(response).not_to render_template :show
            expect(response).to redirect_to idv_please_call_url
          end
        end

        context 'in_person_proofing_enforce_tmx enabled, pending fraud review, enrollment passed' do
          let(:in_person_proofing_enforce_tmx) { true }
          let!(:profile) { create(:profile, fraud_review_pending_at: 1.day.ago, user: user) }
          let!(:enrollment) { create(:in_person_enrollment, :passed, user: user, profile: profile) }

          it 'redirects to please call' do
            response

            expect(response).to redirect_to idv_please_call_url
          end
        end

        context 'in_person_proofing_enforce_tmx enabled, pending fraud review,
          enrollment not passed' do
          let(:in_person_proofing_enforce_tmx) { true }
          let!(:profile) { create(:profile, fraud_review_pending_at: 1.day.ago, user: user) }
          let!(:enrollment) do
            create(:in_person_enrollment, :establishing, user: user, profile: profile)
          end

          it 'does not redirect to please call' do
            response

            expect(response).to render_template :show
            expect(response).not_to redirect_to idv_please_call_url
          end
        end
      end
    end
  end
end
