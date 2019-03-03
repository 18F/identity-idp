require 'rails_helper'

describe Idv::CaptureDocController do
  include DocAuthHelper
  include DocCaptureHelper

  describe 'before_actions' do
    it 'includes corrects before_actions' do
      expect(subject).to have_actions(:before,
                                      :ensure_user_id_in_session,
                                      :fsm_initialize,
                                      :ensure_correct_step)
    end
  end

  let(:user) { create(:user) }
  token = nil

  before do
    enable_doc_auth
    stub_analytics
    allow(@analytics).to receive(:track_event)
    capture_doc = CaptureDoc::CreateRequest.call(user.id)
    token = capture_doc.request_token
  end

  describe '#index' do
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
        Timecop.travel(Time.zone.now + 1.day) do
          get :index, params: { token: token }
        end

        expect(response).to redirect_to root_url
      end
    end

    context 'with a good token' do
      it 'redirects to the first step' do
        get :index, params: { token: token }

        expect(response).to redirect_to idv_capture_doc_step_url(step: :mobile_front_image)
      end
    end

    context 'with a user id in session and no token' do
      it 'redirects to the first step' do
        mock_session(user.id)
        get :index

        expect(response).to redirect_to idv_capture_doc_step_url(step: :mobile_front_image)
      end
    end
  end

  describe '#show' do
    context 'with a user id in session' do
      before do
        mock_session(user.id)
      end

      it 'renders the front_image template' do
        mock_next_step(:mobile_front_image)
        get :show, params: { step: 'mobile_front_image' }

        expect(response).to render_template :mobile_front_image
      end

      it 'renders the back_image template' do
        mock_next_step(:capture_mobile_back_image)
        get :show, params: { step: 'capture_mobile_back_image' }

        expect(response).to render_template :capture_mobile_back_image
      end

      it 'renders the capture_complete template' do
        mock_next_step(:capture_complete)
        get :show, params: { step: 'capture_complete' }

        expect(response).to render_template :capture_complete
      end

      it 'renders a 404 with a non existent step' do
        get :show, params: { step: 'foo' }

        expect(response).to_not be_not_found
      end

      it 'tracks analytics' do
        mock_next_step(:capture_complete)
        result = { step: 'capture_complete' }

        get :show, params: { step: 'capture_complete' }

        expect(@analytics).to have_received(:track_event).with(
          Analytics::CAPTURE_DOC + ' visited', result
        )
      end
    end
  end

  def mock_next_step(step)
    allow_any_instance_of(Idv::Flows::CaptureDocFlow).to receive(:next_step).and_return(step)
  end

  def mock_session(user_id)
    session[:doc_capture_user_id] = user_id
  end
end
