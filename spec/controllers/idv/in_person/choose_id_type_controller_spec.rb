require 'rails_helper'

RSpec.describe Idv::InPerson::ChooseIdTypeController do
  include FlowPolicyHelper

  let(:user) { create(:user) }
  let(:idv_session) { subject.idv_session }

  before do
    stub_request(:get, IdentityConfig.store.dos_passport_composite_healthcheck_endpoint)
      .to_return({ status: 200, body: { status: 'UP' }.to_json })
    stub_sign_in(user)
    stub_up_to(:hybrid_handoff, idv_session: subject.idv_session)
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

        it 'does not log the idv_in_person_proofing_choose_id_type event' do
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

        it 'does not log the idv_in_person_proofing_choose_id_type event' do
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

        before do
          put :update
        end

        it 'returns a no_content response' do
          expect(response).to be_no_content
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
  end
end
