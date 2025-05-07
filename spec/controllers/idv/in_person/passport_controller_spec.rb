require 'rails_helper'

RSpec.describe Idv::InPerson::PassportController do
  include FlowPolicyHelper

  let(:user) { create(:user) }
  let(:document_capture_session) do
    create(:document_capture_session, user:, passport_status: 'requested')
  end
  let(:idv_session) { subject.idv_session }
  let(:enrollment) { InPersonEnrollment.new }

  before do
    stub_sign_in(user)
    stub_up_to(:hybrid_handoff, idv_session: subject.idv_session)
    allow(user).to receive(:establishing_in_person_enrollment).and_return(enrollment)
    subject.idv_session.document_capture_session_uuid = document_capture_session.uuid
    subject.user_session['idv/in_person'] = { pii_from_user: {} }
    stub_analytics
  end

  describe 'before_actions' do
    before do
      allow(idv_session).to receive(:in_person_passports_allowed?).and_return(true)
    end

    it 'includes before_action' do
      expect(subject).to have_actions(:before, :confirm_step_allowed)
      expect(subject).to have_actions(:before, :initialize_pii_from_user)
    end
  end

  describe '#show' do
    context 'when in person passports are not allowed' do
      before do
        allow(idv_session).to receive(:in_person_passports_allowed?).and_return(false)
      end

      it 'does not render the passport form' do
        expect(response).to_not render_template 'idv/in_person/passport/show'
      end

      it 'does not log the idv_in_person_proofing_passport_visited event' do
        expect(@analytics).to_not have_logged_event(:idv_in_person_proofing_passport_visited)
      end
    end

    context 'when in person passports are allowed' do
      before do
        allow(idv_session).to receive(:in_person_passports_allowed?).and_return(true)
      end

      let(:analytics_arguments) do
        {
          step: 'passport',
          analytics_id: 'In Person Proofing',
          skip_hybrid_handoff: false,
        }
      end

      before do
        subject.idv_session.opted_in_to_in_person_proofing =
          analytics_arguments[:opted_in_to_in_person_proofing]
        subject.idv_session.skip_hybrid_handoff = analytics_arguments[:skip_hybrid_handoff]
      end

      context 'when document_capture_session is "requested"' do
        before do
          get :show
        end

        it 'renders the passport form' do
          expect(response).to render_template 'idv/in_person/passport/show'
        end

        it 'logs the idv_in_person_proofing_passport_visited event' do
          expect(@analytics).to have_logged_event(
            :idv_in_person_proofing_passport_visited,
            analytics_arguments,
          )
        end
      end

      context 'when document_capture_session is "not_requested"' do
        before do
          subject.document_capture_session.update!(passport_status: 'not_requested')
          get :show
        end

        it 'does not render the passport form' do
          expect(response).to_not render_template 'idv/in_person/passport/show'
        end

        it 'does not log the idv_in_person_proofing_passport_visited event' do
          expect(@analytics).to_not have_logged_event(:idv_in_person_proofing_passport_visited)
        end
      end
    end
  end

  describe '#update' do
    before do
      allow(idv_session).to receive(:in_person_passports_allowed?).and_return(true)
      put :update
    end

    it 'redirects to the address form' do
      expect(response).to redirect_to(idv_in_person_address_path)
    end
  end
end
