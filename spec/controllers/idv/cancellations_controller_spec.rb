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

      expect(@analytics).to receive(:track_event).with(
        'IdV: cancellation visited',
        request_came_from: 'no referer',
        step: nil,
        proofing_components: nil,
      )

      get :new
    end

    it 'tracks the event in analytics when referer is present' do
      stub_sign_in
      stub_analytics
      request.env['HTTP_REFERER'] = 'http://example.com/'

      expect(@analytics).to receive(:track_event).with(
        'IdV: cancellation visited',
        request_came_from: 'users/sessions#new',
        step: nil,
        proofing_components: nil,
      )

      get :new
    end

    it 'tracks the event in analytics when step param is present' do
      stub_sign_in
      stub_analytics

      expect(@analytics).to receive(:track_event).with(
        'IdV: cancellation visited',
        request_came_from: 'no referer',
        step: 'first',
        proofing_components: nil,
      )

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
        proofing_components: nil,
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
        proofing_components: nil,
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
      let(:user) { create(:user) }

      before do
        stub_sign_in(user)
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

      context 'with in person enrollment' do
        let(:user) { build(:user, :with_pending_in_person_enrollment) }

        before do
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
          allow(controller).to receive(:user_session).and_return(
            'idv/in_person' => { 'pii_from_user' => {},
                                 'Idv::Steps::InPerson::StateIdStep' => true,
                                 'Idv::Steps::InPerson::AddressStep' => true },
          )
        end

        it 'cancels pending in person enrollment' do
          pending_enrollment = user.pending_in_person_enrollment
          expect(user.reload.pending_in_person_enrollment).to_not be_blank
          delete :destroy

          pending_enrollment.reload
          expect(pending_enrollment.status).to eq('cancelled')
          expect(user.reload.pending_in_person_enrollment).to be_blank
        end

        it 'cancels establishing in person enrollment' do
          establishing_enrollment = create(:in_person_enrollment, :establishing, user: user)
          expect(InPersonEnrollment.where(user: user, status: :establishing).count).to eq(1)
          delete :destroy

          establishing_enrollment.reload
          expect(establishing_enrollment.status).to eq('cancelled')
          expect(InPersonEnrollment.where(user: user, status: :establishing).count).to eq(0)
        end

        it 'deletes in person flow data' do
          expect(controller.user_session['idv/in_person']).not_to be_blank
          delete :destroy

          expect(controller.user_session['idv/in_person']).to be_blank
        end
      end
    end
  end
end
