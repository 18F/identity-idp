require 'rails_helper'

describe Idv::RecoveryController do
  include DocAuthHelper

  describe 'before_actions' do
    it 'includes corrects before_actions' do
      expect(subject).to have_actions(:before,
                                      :ensure_user_id_in_session,
                                      :fsm_initialize,
                                      :ensure_correct_step)
    end
  end

  before do |example|
    stub_sign_in unless example.metadata[:skip_sign_in]
    stub_analytics
    allow(@analytics).to receive(:track_event)
  end

  describe 'before_actions' do
    it 'includes before_actions from IdvSession' do
      expect(subject).to have_actions(:before, :redirect_if_sp_context_needed)
    end
  end

  describe 'unauthenticated', :skip_sign_in do
    it 'redirects to the root url' do
      get :index

      expect(response).to redirect_to root_url
    end
  end

  describe '#index' do
    let(:user) { create(:user) }
    let(:token) { Recover::CreateRecoverRequest.call(user.id).request_token }

    context 'with no token' do
      it 'redirects to the root url' do
        get :index

        expect(response).to redirect_to root_url
      end
    end

    context 'with a bad token' do
      it 'redirects to the root url' do
        get :index, params: { token: 'foo' }

        expect(response).to redirect_to root_url
      end
    end

    context 'with an expired token' do
      it 'redirects to the root url' do
        expired_token = Recover::CreateRecoverRequest.call(user.id).request_token
        Timecop.travel(Time.zone.now + 1.day) do
          get :index, params: { token: expired_token }
        end

        expect(response).to redirect_to root_url
      end
    end

    context 'with a good token' do
      it 'redirects to the first step' do
        get :index, params: { token: token }

        expect(response).to redirect_to idv_recovery_step_url(step: :recover)
      end
    end

    context 'with a user id in session and no token' do
      it 'redirects to the first step' do
        mock_session(user.id)
        get :index

        expect(response).to redirect_to idv_recovery_step_url(step: :recover)
      end
    end
  end

  describe '#show' do
    let(:user) { create(:user) }
    let(:token) { Recover::CreateRecoverRequest.call(user.id).request_token }

    context 'with a user id in session' do
      before do
        mock_session(user.id)
      end

      it 'renders the document_capture template' do
        expect(subject).to receive(:render).with(
          template: 'layouts/flow_step',
          locals: hash_including(
            :back_image_upload_url,
            :front_image_upload_url,
            :selfie_image_upload_url,
            :flow_session,
            step_template: 'idv/doc_auth/document_capture',
            flow_namespace: 'idv',
            step_indicator: hash_including(
              :steps,
              current_step: :verify_id,
            ),
          ),
        ).and_call_original

        mock_next_step(:document_capture)
        get :show, params: { step: 'document_capture' }
      end

      it 'redirect to the right step' do
        mock_next_step(:document_capture)
        get :show, params: { step: 'ssn' }

        expect(response).to redirect_to idv_recovery_step_url(:document_capture)
      end

      it 'renders a 404 with a non existent step' do
        get :show, params: { step: 'foo' }

        expect(response).to_not be_not_found
      end

      it 'tracks analytics' do
        result = { step: 'recover', flow_path: 'standard', step_count: 1 }

        get :show, params: { step: 'recover' }

        expect(@analytics).to have_received(:track_event).with(
          Analytics::IAL2_RECOVERY + ' visited', result
        )
      end
    end
  end

  def mock_next_step(step)
    allow_any_instance_of(Idv::Flows::RecoveryFlow).to receive(:next_step).and_return(step)
  end

  def mock_session(user_id)
    session[:ial2_recovery_user_id] = user_id
  end
end
