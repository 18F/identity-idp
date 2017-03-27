require 'rails_helper'

describe SignUp::CompletionsController do
  describe '#show' do
    context 'user signed in, sp info present' do
      before do
        stub_analytics
        allow(@analytics).to receive(:track_event)
      end

      context 'LOA1' do
        it 'tracks page visit' do
          stub_sign_in
          subject.session[:sp] = { loa3: false }
          get :show

          expect(@analytics).to have_received(:track_event).with(
            Analytics::USER_REGISTRATION_AGENCY_HANDOFF_PAGE_VISIT,
            loa3: false, service_provider_name: subject.decorated_session.sp_name
          )
        end
      end

      context 'LOA3' do
        it 'tracks page visit' do
          user = create(:user, profiles: [create(:profile, :verified, :active)])
          stub_sign_in(user)
          subject.session[:sp] = { loa3: true }

          get :show

          expect(@analytics).to have_received(:track_event).with(
            Analytics::USER_REGISTRATION_AGENCY_HANDOFF_PAGE_VISIT,
            loa3: true, service_provider_name: subject.decorated_session.sp_name
          )
        end
      end
    end

    it 'requires user to be logged in' do
      subject.session[:sp] = { dog: 'max' }
      get :show

      expect(response).to redirect_to(new_user_session_url)
    end

    it 'requires service provider info in session' do
      stub_sign_in
      subject.session[:sp] = {}

      get :show

      expect(response).to redirect_to(new_user_session_url)
    end
  end

  describe '#update' do
    before do
      stub_analytics
      allow(@analytics).to receive(:track_event)
    end

    context 'LOA1' do
      it 'tracks analytics' do
        stub_sign_in
        subject.session[:sp] = {
          loa3: false,
          request_url: 'http://example.com',
        }

        patch :update

        expect(@analytics).to have_received(:track_event).with(
          Analytics::USER_REGISTRATION_AGENCY_HANDOFF_COMPLETE,
          loa3: false, service_provider_name: subject.decorated_session.sp_name
        )
      end
    end

    context 'LOA3' do
      it 'tracks analytics' do
        user = create(:user, profiles: [create(:profile, :verified, :active)])
        stub_sign_in(user)
        subject.session[:sp] = {
          loa3: true,
          request_url: 'http://example.com',
        }

        patch :update

        expect(@analytics).to have_received(:track_event).with(
          Analytics::USER_REGISTRATION_AGENCY_HANDOFF_COMPLETE,
          loa3: true, service_provider_name: subject.decorated_session.sp_name
        )
      end
    end
  end
end
