require 'rails_helper'

RSpec.describe Idv::InPerson::ReadyToVerifyController do
  let(:user) { create(:user) }
  let(:in_person_proofing_enabled) { false }
  let(:in_person_proofing_enforce_tmx) { false }

  before do
    stub_analytics
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled)
      .and_return(in_person_proofing_enabled)
    allow(IdentityConfig.store).to receive(:in_person_proofing_enforce_tmx)
      .and_return(in_person_proofing_enforce_tmx)
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
      stub_sign_in(user)
      expect(response.status).to eq 404
    end

    context 'with in person proofing enabled' do
      let(:in_person_proofing_enabled) { true }
      let(:ipp_post_office_closed_alert_enabled) { false }

      context 'authenticated' do
        before do
          stub_sign_in(user)
        end

        it 'redirects to account page' do
          expect(response).to redirect_to account_url
        end

        context 'with enrollment' do
          let(:user) { create(:user, :with_pending_in_person_enrollment) }

          it 'renders show template' do
            expect(response).to render_template :show
          end

          it 'logs analytics' do
            response

            expect(@analytics).to have_logged_event('IdV: in person ready to verify visited')
          end

          context 'with in_person_proofing_enforce_tmx disabled and pending fraud review' do
            let!(:profile) { create(:profile, fraud_review_pending_at: 1.day.ago, user: user) }
            let!(:enrollment) do
              create(:in_person_enrollment, :passed, user: user, profile: profile)
            end
            it 'redirects to please call page' do
              response

              expect(response).not_to render_template :show
              expect(response).to redirect_to idv_please_call_url
            end
          end

          context 'in_person_proofing_enforce_tmx enabled, pending fraud review, enrollment pass' do
            let(:in_person_proofing_enforce_tmx) { true }
            let!(:profile) { create(:profile, fraud_review_pending_at: 1.day.ago, user: user) }
            let!(:enrollment) do
              create(:in_person_enrollment, :passed, user: user, profile: profile)
            end

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

          context 'when vtr (vector of trust) does not include Enhanced Proofing (Pe)' do
            before do
              resolved_authn_context_result = Vot::Parser.new(vector_of_trust: 'Pb').parse

              allow(controller).to receive(:resolved_authn_context_result)
                .and_return(resolved_authn_context_result)
            end

            it 'evaluates to In Person Proofing' do
              response

              expect(assigns(:is_enhanced_ipp)).to be false
            end
          end

          context 'when vtr (vector of trust) includes Enhanced Proofing (Pe)' do
            before do
              resolved_authn_context_result = Vot::Parser.new(vector_of_trust: 'Pe').parse

              allow(controller).to receive(:resolved_authn_context_result)
                .and_return(resolved_authn_context_result)
            end

            it 'evaluates to Enhanced IPP' do
              response

              expect(assigns(:is_enhanced_ipp)).to be true
            end
          end

          context 'with in_person_proofing_post_office_closed_alert_enabled' do
            let(:ipp_post_office_closed_alert_enabled) { true }
            before do
              allow(IdentityConfig.store)
                .to receive(:in_person_proofing_post_office_closed_alert_enabled)
                .and_return(ipp_post_office_closed_alert_enabled)
            end

            it 'renders the show template' do
              expect(response).to render_template :show
            end
          end
        end
      end

      context 'with hybrid session' do
        let(:in_person_proofing_enforce_tmx) { true }
        it 'redirects to root' do
          controller.session[:doc_capture_user_id] = user.id

          expect(response).to redirect_to(new_user_session_url)
        end
      end
    end
  end
end
