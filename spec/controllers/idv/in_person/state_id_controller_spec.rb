require 'rails_helper'

RSpec.describe Idv::InPerson::StateIdController do
  include FlowPolicyHelper
  include InPersonHelper

  let(:user) { build(:user) }
  let(:enrollment) { InPersonEnrollment.new }

  let(:ab_test_args) do
    { sample_bucket1: :sample_value1, sample_bucket2: :sample_value2 }
  end

  before do
    allow(IdentityConfig.store).to receive(:in_person_state_id_controller_enabled).
      and_return(true)
    allow(IdentityConfig.store).to receive(:usps_ipp_transliteration_enabled).
      and_return(true)
    stub_sign_in(user)
    stub_up_to(:hybrid_handoff, idv_session: subject.idv_session)
    allow(user).to receive(:establishing_in_person_enrollment).and_return(enrollment)
    subject.user_session['idv/in_person'] = { pii_from_user: {} }
    subject.idv_session.ssn = nil # This made specs pass. Might need more investigation.
    stub_analytics
    allow(@analytics).to receive(:track_event)
    allow(subject).to receive(:ab_test_analytics_buckets).and_return(ab_test_args)
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::InPerson::StateIdController.step_info).to be_valid
    end
  end

  describe 'before_actions' do
    context '#render_404_if_controller_not_enabled' do
      context 'flag not set' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_state_id_controller_enabled).
            and_return(nil)
        end
        it 'renders a 404' do
          get :show

          expect(response).to be_not_found
        end
      end

      context 'flag not enabled' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_state_id_controller_enabled).
            and_return(false)
        end
        it 'renders a 404' do
          get :show

          expect(response).to be_not_found
        end
      end
    end

    context '#confirm_establishing_enrollment' do
      let(:enrollment) { nil }
      it 'redirects to document capture if not complete' do
        get :show

        expect(response).to redirect_to idv_document_capture_url
      end
    end
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: in person proofing state_id visited' }
    let(:analytics_args) do
      {
        analytics_id: 'In Person Proofing',
        flow_path: 'standard',
        irs_reproofing: false,
        opted_in_to_in_person_proofing: nil,
        step: 'state_id',
        pii_like_keypaths: [[:same_address_as_id],
                            [:proofing_results, :context, :stages, :state_id,
                             :state_id_jurisdiction]],
      }.merge(ab_test_args)
    end

    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end

    context 'pii_from_user is nil' do
      it 'renders the show template' do
        subject.user_session['idv/in_person'].delete(:pii_from_user)
        get :show

        expect(response).to render_template :show
      end
    end

    it 'logs idv_in_person_proofing_state_id_visited' do
      get :show

      expect(@analytics).to have_received(
        :track_event,
      ).with(analytics_name, analytics_args)
    end

    it 'has correct extra_view_variables' do
      expect(subject.extra_view_variables).to include(
        form: Idv::StateIdForm,
        updating_state_id: false,
      )

      expect(subject.extra_view_variables[:pii]).to_not have_key(
        :address1,
      )
    end
  end
end
