require 'rails_helper'

describe Idv::CancellationsController do
  describe 'before_actions' do
    it 'includes before_actions from IdvSession' do
      expect(subject).to have_actions(:before, :redirect_if_sp_context_needed)
    end
  end

  describe '#new' do
    let(:go_back_path) { '/path/to/return' }

    before do
      allow(controller).to receive(:go_back_path).and_return(go_back_path)
    end

    it 'tracks the event in analytics when referer is nil' do
      stub_sign_in
      stub_analytics
      properties = { request_came_from: 'no referer', step: nil }

      expect(@analytics).to receive(:track_event).with('IdV: cancellation visited', properties)

      get :new
    end

    it 'tracks the event in analytics when referer is present' do
      stub_sign_in
      stub_analytics
      request.env['HTTP_REFERER'] = 'http://example.com/'
      properties = { request_came_from: 'users/sessions#new', step: nil }

      expect(@analytics).to receive(:track_event).with('IdV: cancellation visited', properties)

      get :new
    end

    it 'tracks the event in analytics when step param is present' do
      stub_sign_in
      stub_analytics
      properties = { request_came_from: 'no referer', step: 'first' }

      expect(@analytics).to receive(:track_event).with('IdV: cancellation visited', properties)

      get :new, params: { step: 'first' }
    end

    context 'when no session' do
      it 'redirects to root' do
        get :new

        expect(response).to redirect_to(root_url)
      end
    end

    context 'when hybrid session' do
      before do
        session[:doc_capture_user_id] = create(:user).id
      end

      it 'renders template' do
        get :new

        expect(response).to render_template(:new)
      end

      it 'stores go back path' do
        get :new

        expect(session[:go_back_path]).to eq(go_back_path)
      end
    end

    context 'when regular session' do
      before do
        stub_sign_in
      end

      it 'renders template' do
        get :new

        expect(response).to render_template(:new)
      end

      it 'stores go back path' do
        get :new

        expect(controller.user_session[:idv][:go_back_path]).to eq(go_back_path)
      end
    end
  end

  describe '#update' do
    before do
      stub_sign_in
      stub_analytics
    end

    it 'logs cancellation go back' do
      expect(@analytics).to receive(:track_event).with(
        'IdV: cancellation go back',
        step: 'first',
      )

      put :update, params: { step: 'first', cancel: 'true' }
    end

    it 'redirects to idv_path' do
      put :update, params: { cancel: 'true' }

      expect(response).to redirect_to idv_url
    end

    context 'with go back path stored in session' do
      let(:go_back_path) { '/path/to/return' }

      before do
        allow(controller).to receive(:user_session).and_return(
          idv: { go_back_path: go_back_path },
        )
      end

      it 'redirects to go back path' do
        put :update, params: { cancel: 'true' }

        expect(response).to redirect_to go_back_path
      end
    end
  end

  describe '#destroy' do
    it 'tracks an analytics event' do
      stub_sign_in
      stub_analytics

      expect(@analytics).to receive(:track_event).with(
        'IdV: cancellation confirmed',
        step: 'first',
      )

      delete :destroy, params: { step: 'first' }
    end

    context 'when no session' do
      it 'redirects to root' do
        delete :destroy

        expect(response).to redirect_to(root_url)
      end
    end

    context 'when hybrid session' do
      let(:user) { create(:user) }
      let(:document_capture_session) { user.document_capture_sessions.create! }
      before do
        session[:doc_capture_user_id] = user.id
        session[:document_capture_session_uuid] = document_capture_session.uuid
      end

      it 'cancels document capture' do
        delete :destroy

        expect(document_capture_session.reload.cancelled_at).to be_present
      end

      it 'renders template' do
        delete :destroy

        expect(response).to render_template(:destroy)
      end
    end

    context 'when regular session' do
      before do
        stub_sign_in
      end

      it 'destroys session' do
        expect(subject.user_session).to receive(:delete).with('idv/doc_auth')

        delete :destroy
      end

      it 'renders template' do
        delete :destroy

        parsed_body = JSON.parse(response.body, symbolize_names: true)
        expect(response).not_to render_template(:destroy)
        expect(parsed_body).to eq({ redirect_url: account_path })
      end
    end
  end
end
