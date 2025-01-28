require 'rails_helper'

RSpec.describe Idv::CancellationsController do
  describe 'before_actions' do
    it 'includes before_actions from IdvSessionConcern' do
      expect(subject).to have_actions(:before, :redirect_unless_sp_requested_verification)
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

      get :new

      expect(@analytics).to have_logged_event(
        'IdV: cancellation visited',
        hash_including(
          request_came_from: 'no referer',
        ),
      )
    end

    it 'tracks the event in analytics when referer is present' do
      stub_sign_in
      stub_analytics
      request.env['HTTP_REFERER'] = 'http://example.com/'

      get :new

      expect(@analytics).to have_logged_event(
        'IdV: cancellation visited',
        hash_including(
          request_came_from: 'users/sessions#new',
        ),
      )
    end

    it 'tracks the event in analytics when step param is present' do
      stub_sign_in
      stub_analytics

      get :new, params: { step: 'first' }

      expect(@analytics).to have_logged_event(
        'IdV: cancellation visited',
        hash_including(
          request_came_from: 'no referer',
          step: 'first',
        ),
      )
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
    let(:user) { create(:user) }

    before do
      stub_sign_in(user)
      stub_analytics
    end

    it 'logs cancellation go back' do
      put :update, params: { step: 'first', cancel: 'true' }

      expect(@analytics).to have_logged_event(
        'IdV: cancellation go back',
        hash_including(
          step: 'first',
        ),
      )
    end

    it 'redirects to idv_path' do
      put :update, params: { cancel: 'true' }

      expect(response).to redirect_to idv_url
    end

    context 'in-person proofing' do
      let!(:enrollment) { create(:in_person_enrollment, :pending, user: user) }

      it 'logs cancellation go back with extra analytics attributes for barcode step' do
        put :update, params: { step: 'barcode', cancel: 'true' }

        expect(@analytics).to have_logged_event(
          'IdV: cancellation go back',
          hash_including(
            step: 'barcode',
            cancelled_enrollment: false,
            enrollment_code: enrollment.enrollment_code,
            enrollment_id: enrollment.id,
          ),
        )
      end
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

      delete :destroy, params: { step: 'first' }

      expect(@analytics).to have_logged_event(
        'IdV: cancellation confirmed',
        hash_including(step: 'first'),
      )
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

      it 'renders template' do
        delete :destroy

        parsed_body = JSON.parse(response.body, symbolize_names: true)
        expect(response).not_to render_template(:destroy)
        expect(parsed_body).to eq({ redirect_url: account_path })
      end

      context 'with in establishing in-person enrollment' do
        let(:user) { build(:user, :with_establishing_in_person_enrollment) }
        let!(:enrollment) { user.establishing_in_person_enrollment }

        before do
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
          allow(controller).to receive(:user_session).and_return(
            'idv/in_person' => { 'pii_from_user' => {} },
          )
          delete :destroy
          enrollment.reload
        end

        it 'cancels establishing in person enrollment' do
          expect(enrollment.status).to eq(InPersonEnrollment::STATUS_CANCELLED)
          expect(InPersonEnrollment.where(user: user, status: :establishing).count).to eq(0)
        end

        it 'deletes in person flow data' do
          expect(controller.user_session['idv/in_person']).to be_blank
        end
      end

      context 'with in pending in-person enrollment' do
        let(:user) { build(:user, :with_pending_in_person_enrollment) }
        let(:enrollment) { user.pending_in_person_enrollment }

        before do
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
          allow(controller).to receive(:user_session).and_return(
            'idv/in_person' => { 'pii_from_user' => {} },
          )

          delete :destroy
          enrollment.reload
        end

        it 'does not cancel pending in person enrollments' do
          expect(enrollment.status).to eq(InPersonEnrollment::STATUS_PENDING)
          expect(InPersonEnrollment.where(user: user, status: :pending).count).to eq(1)
        end

        it 'deletes in person flow data' do
          expect(controller.user_session['idv/in_person']).to be_blank
        end
      end
    end
  end
end
