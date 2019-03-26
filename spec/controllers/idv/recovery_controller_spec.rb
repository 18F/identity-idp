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
    enable_doc_auth
    stub_sign_in unless example.metadata[:skip_sign_in]
    stub_analytics
    allow(@analytics).to receive(:track_event)
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

      it 'renders the front_image template' do
        mock_next_step(:ssn)
        get :show, params: { step: 'ssn' }

        expect(response).to render_template :ssn
      end

      it 'renders the front_image template' do
        mock_next_step(:front_image)
        get :show, params: { step: 'front_image' }

        expect(response).to render_template :front_image
      end

      it 'renders the back_image template' do
        mock_next_step(:back_image)
        get :show, params: { step: 'back_image' }

        expect(response).to render_template :back_image
      end

      it 'redirect to the right step' do
        mock_next_step(:front_image)
        get :show, params: { step: 'back_image' }

        expect(response).to redirect_to idv_recovery_step_url(:front_image)
      end

      it 'renders a 404 with a non existent step' do
        get :show, params: { step: 'foo' }

        expect(response).to_not be_not_found
      end

      it 'tracks analytics' do
        result = { step: 'recover' }

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
