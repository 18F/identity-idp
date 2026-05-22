require 'rails_helper'

RSpec.describe Idv::EnterDobSsnController do
  let(:success) { true }
  let(:pii) do
    {
      ssn: '123456789',
      dob: '1990-01-01',
    }
  end
  let(:agent_proofed_user) do
    {
      pii: pii,
      success: success,
    }
  end
  let(:user) { create(:user, :fully_registered) }
  let(:document_capture_session) { DocumentCaptureSession.create!(user: user) }
  let(:idv_session) { subject.idv_session }

  before do
    stub_sign_in(user)
    document_capture_session.store_agent_proofed_user(agent_proofed_user)
  end

  describe 'before_actions' do
    it 'includes before_actions' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :move_agent_proofed_user_pii_to_idv_session,
      )
    end

    it 'includes before_actions from IdvSessionConcern' do
      expect(subject).to have_actions(:before, :redirect_unless_sp_requested_verification)
    end
  end

  describe '#new' do
    it 'moves agent proofed user pii to idv_session applicant' do
      get :new
      expect(subject.idv_session.applicant).to eq(pii.stringify_keys)
    end
  end

  describe '#create' do
    before { get :new }

    context 'user typed dob and ssn matches idv_session.applicant dob and ssn' do
      it 'redirects to enter password step' do
        post :create, params: {
          doc_auth: {
            ssn: pii[:ssn],
            dob: { year: '1990', month: '01', day: '01' },
          },
        }
        expect(response).to redirect_to(idv_enter_password_url)
      end
    end

    context 'user typed ssn does not match idv_session.applicant ssn' do
      it 'renders new' do
        post :create, params: {
          doc_auth: {
            ssn: '000000000',
            dob: { year: '1990', month: '01', day: '01' },
          },
        }
        expect(response).to render_template(:new)
      end
    end

    context 'user typed dob does not match idv_session.applicant dob' do
      it 'renders new' do
        post :create, params: {
          doc_auth: {
            ssn: pii[:ssn],
            dob: { year: '2000', month: '06', day: '15' },
          },
        }
        expect(response).to render_template(:new)
      end
    end
  end
end
