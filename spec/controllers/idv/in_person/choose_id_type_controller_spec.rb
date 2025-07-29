require 'rails_helper'

RSpec.describe Idv::InPerson::ChooseIdTypeController do
  include FlowPolicyHelper

  let(:user) { create(:user) }
  let(:document_capture_session) do
    create(:document_capture_session, user:, passport_status: 'allowed')
  end
  let(:idv_session) { subject.idv_session }

  before do
    stub_request(:get, IdentityConfig.store.dos_passport_composite_healthcheck_endpoint)
      .to_return({ status: 200, body: { status: 'UP' }.to_json })
    stub_sign_in(user)
    subject.idv_session.document_capture_session_uuid = document_capture_session.uuid
    stub_up_to(:ipp, idv_session: subject.idv_session)
    allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled).and_return(true)
    stub_analytics
  end

  describe 'before_actions' do
    it 'includes confirm step allowed before_action' do
      expect(subject).to have_actions(:before, :confirm_step_allowed)
    end
  end

  describe '#show' do
    context 'when in person passports are allowed' do
      before do
        allow(idv_session).to receive(:in_person_passports_allowed?).and_return(true)
      end

      context 'when the user has an existing establishing enrollment' do
        let!(:enrollment) { create(:in_person_enrollment, :establishing, user: user) }
        let(:analytics_arguments) do
          {
            flow_path: 'standard',
            step: 'choose_id_type',
            analytics_id: 'In Person Proofing',
            skip_hybrid_handoff: false,
            opted_in_to_in_person_proofing: true,
          }
        end

        before do
          subject.idv_session.opted_in_to_in_person_proofing =
            analytics_arguments[:opted_in_to_in_person_proofing]
          subject.idv_session.skip_hybrid_handoff = analytics_arguments[:skip_hybrid_handoff]
          get :show
        end

        it 'renders the choose id type form' do
          expect(response).to render_template 'idv/shared/choose_id_type'
        end

        it 'logs the idv_in_person_proofing_choose_id_type event' do
          expect(@analytics).to have_logged_event(
            :idv_in_person_proofing_choose_id_type_visited, analytics_arguments
          )
        end
      end

      context 'when the user does not have an existing establishing enrollment' do
        before do
          get :show
        end

        it 'returns a redirect' do
          expect(response).to be_redirect
        end

        it 'does not log the idv_in_person_proofing_choose_id_type event' do
          expect(@analytics).to_not have_logged_event(
            :idv_in_person_proofing_choose_id_type_visited,
          )
        end
      end
    end

    context 'when in person passports are not allowed' do
      before do
        allow(idv_session).to receive(:in_person_passports_allowed?).and_return(false)
      end

      context 'when the user has an existing establishing enrollment' do
        let!(:enrollment) { create(:in_person_enrollment, :establishing, user: user) }
        let(:analytics_arguments) do
          {
            flow_path: 'standard',
            step: 'choose_id_type',
            analytics_id: 'In Person Proofing',
            skip_hybrid_handoff: false,
            opted_in_to_in_person_proofing: true,
          }
        end

        before do
          subject.idv_session.opted_in_to_in_person_proofing =
            analytics_arguments[:opted_in_to_in_person_proofing]
          subject.idv_session.skip_hybrid_handoff = analytics_arguments[:skip_hybrid_handoff]
          get :show
        end

        it 'returns a redirect response' do
          expect(response).to be_redirect
        end

        it 'does not log the idv_in_person_proofing_choose_id_type_visited event' do
          expect(@analytics).to_not have_logged_event(
            :idv_in_person_proofing_choose_id_type_visited,
          )
        end
      end

      context 'when the user does not have an existing establishing enrollment' do
        before do
          get :show
        end

        it 'returns a redirect response' do
          expect(response).to be_redirect
        end

        it 'does not log the idv_in_person_proofing_choose_id_type_visited event' do
          expect(@analytics).to_not have_logged_event(
            :idv_in_person_proofing_choose_id_type_visited,
          )
        end
      end
    end
  end

  describe '#update' do
    context 'when in person passports are allowed' do
      before do
        allow(idv_session).to receive(:in_person_passports_allowed?).and_return(true)
      end

      context 'when the user has an existing establishing enrollment' do
        let!(:enrollment) { create(:in_person_enrollment, :establishing, user: user) }

        context 'when the form submission is successful' do
          context 'when the chosen ID type is "passport"' do
            let(:chosen_id_type) { 'passport' }
            let(:params) do
              {
                doc_auth: {
                  choose_id_type_preference: chosen_id_type,
                },
              }
            end
            let(:analytics_arguments) do
              {
                flow_path: 'standard',
                step: 'choose_id_type',
                analytics_id: 'In Person Proofing',
                skip_hybrid_handoff: false,
                opted_in_to_in_person_proofing: true,
                chosen_id_type: chosen_id_type,
                success: true,
              }
            end

            before do
              subject.idv_session.opted_in_to_in_person_proofing =
                analytics_arguments[:opted_in_to_in_person_proofing]
              subject.idv_session.skip_hybrid_handoff = analytics_arguments[:skip_hybrid_handoff]
              put :update, params: params
            end

            it 'logs the idv_in_person_proofing_choose_id_type_submitted event' do
              expect(@analytics).to have_logged_event(
                :idv_in_person_proofing_choose_id_type_submitted, analytics_arguments
              )
            end

            it 'updates the passport status to "requested" in document capture session' do
              expect(controller.document_capture_session.passport_status).to eq('requested')
            end

            it 'redirects to the in person passport page' do
              expect(response).to redirect_to(idv_in_person_passport_path)
            end
          end

          context 'when the chosen ID type is "drivers_license"' do
            let(:chosen_id_type) { 'drivers_license' }
            let(:params) do
              {
                doc_auth: {
                  choose_id_type_preference: chosen_id_type,
                },
              }
            end
            let(:analytics_arguments) do
              {
                flow_path: 'standard',
                step: 'choose_id_type',
                analytics_id: 'In Person Proofing',
                skip_hybrid_handoff: false,
                opted_in_to_in_person_proofing: true,
                chosen_id_type: chosen_id_type,
                success: true,
              }
            end

            before do
              subject.idv_session.opted_in_to_in_person_proofing =
                analytics_arguments[:opted_in_to_in_person_proofing]
              subject.idv_session.skip_hybrid_handoff = analytics_arguments[:skip_hybrid_handoff]
              put :update, params: params
            end

            it 'logs the idv_in_person_proofing_choose_id_type_submitted event' do
              expect(@analytics).to have_logged_event(
                :idv_in_person_proofing_choose_id_type_submitted, analytics_arguments
              )
            end

            it 'updates the passport status to "not_requested" in document capture session' do
              expect(controller.document_capture_session.passport_status).to eq('not_requested')
            end

            it 'redirects to the in person state ID page' do
              expect(response).to redirect_to(idv_in_person_state_id_path)
            end
          end
        end

        context 'when the form submission is not successful' do
          let(:params) do
            {
              doc_auth: {
                choose_id_type_preference: '',
              },
            }
          end
          let(:analytics_arguments) do
            {
              flow_path: 'standard',
              step: 'choose_id_type',
              analytics_id: 'In Person Proofing',
              skip_hybrid_handoff: false,
              opted_in_to_in_person_proofing: true,
              chosen_id_type: '',
              success: false,
              error_details: { chosen_id_type: { invalid: true } },
            }
          end

          before do
            subject.idv_session.opted_in_to_in_person_proofing =
              analytics_arguments[:opted_in_to_in_person_proofing]
            subject.idv_session.skip_hybrid_handoff = analytics_arguments[:skip_hybrid_handoff]
            put :update, params: params
          end

          it 'logs the idv_in_person_proofing_choose_id_type_submitted event' do
            expect(@analytics).to have_logged_event(
              :idv_in_person_proofing_choose_id_type_submitted, analytics_arguments
            )
          end

          it 'does not update the passport status in document_capture_session' do
            expect(controller.document_capture_session.passport_status).to eq('allowed')
          end

          it 'redirects to the in in person choose id type page' do
            expect(response).to redirect_to(idv_in_person_choose_id_type_path)
          end
        end
      end

      context 'when the user does not have an existing establishing enrollment' do
        before do
          put :update
        end

        it 'returns a redirect response' do
          expect(response).to be_redirect
        end
      end
    end

    context 'when in person passports are not allowed' do
      before do
        allow(idv_session).to receive(:in_person_passports_allowed?).and_return(false)
      end

      context 'when the user has an existing establishing enrollment' do
        let!(:enrollment) { create(:in_person_enrollment, :establishing, user: user) }

        before do
          put :update
        end

        it 'returns a redirect response' do
          expect(response).to be_redirect
        end
      end

      context 'when the user does not have an existing establishing enrollment' do
        before do
          put :update
        end

        it 'returns a redirect response' do
          expect(response).to be_redirect
        end
      end
    end
  end

  describe '.step_info' do
    it 'returns a valid StepInfo Object' do
      expect(described_class.step_info).to be_valid
    end

    context 'undo_step' do
      let(:user) { create(:user, :with_establishing_in_person_enrollment) }

      before do
        subject.document_capture_session.update!(passport_status: 'requested')
      end

      context 'when idv session has a document capture session uuid' do
        context 'when passports are allowed in idv session' do
          before do
            subject.idv_session.passport_allowed = true
            described_class.step_info.undo_step.call(idv_session: subject.idv_session, user:)
          end

          it 'sets passport status to "allowed" in the document capture session' do
            expect(subject.document_capture_session.reload.passport_status).to eq('allowed')
          end
        end

        context 'when passports are not allowed in idv session' do
          before do
            subject.idv_session.passport_allowed = false
            described_class.step_info.undo_step.call(idv_session: subject.idv_session, user:)
          end

          it 'sets passport status to nil in the document capture session' do
            expect(subject.document_capture_session.reload.passport_status).to eq(nil)
          end
        end
      end

      context 'when idv session does not have a document capture session uuid' do
        before do
          subject.idv_session.document_capture_session_uuid = nil
          described_class.step_info.undo_step.call(idv_session: subject.idv_session, user:)
        end

        it 'does not update the passport status in the document capture session' do
          expect(subject.document_capture_session.reload.passport_status).to eq('requested')
        end
      end
    end
  end
end
