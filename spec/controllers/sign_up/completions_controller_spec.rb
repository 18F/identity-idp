require 'rails_helper'

describe SignUp::CompletionsController do
  describe '#show' do
    context 'user signed in, sp info present' do
      before do
        stub_analytics
        allow(@analytics).to receive(:track_event)
      end

      context 'IAL1' do
        it 'tracks page visit' do
          user = create(:user)
          stub_sign_in(user)
          subject.session[:sp] = { issuer: 'awesome sp', ial2: false }
          get :show

          expect(@analytics).to have_received(:track_event).with(
            Analytics::USER_REGISTRATION_AGENCY_HANDOFF_PAGE_VISIT,
            ial2: false,
            service_provider_name: subject.decorated_session.sp_name,
            page_occurence: '',
          )
        end
      end

      context 'IAL2' do
        it 'tracks page visit' do
          user = create(:user, profiles: [create(:profile, :verified, :active)])
          stub_sign_in(user)
          subject.session[:sp] = { issuer: 'awesome sp', ial2: true }

          get :show

          expect(@analytics).to have_received(:track_event).with(
            Analytics::USER_REGISTRATION_AGENCY_HANDOFF_PAGE_VISIT,
            ial2: true,
            service_provider_name: subject.decorated_session.sp_name,
            page_occurence: '',
          )
        end
      end
    end

    it 'requires user with session to be logged in' do
      subject.session[:sp] = { dog: 'max' }
      get :show

      expect(response).to redirect_to(new_user_session_url)
    end

    it 'requires user with no session to be logged in' do
      get :show

      expect(response).to redirect_to(new_user_session_url)
    end

    it 'requires service provider or identity info in session' do
      stub_sign_in
      subject.session[:sp] = {}

      get :show

      expect(response).to redirect_to(account_url)
    end

    it 'requires service provider issuer in session' do
      stub_sign_in
      subject.session[:sp] = { issuer: nil }

      get :show

      expect(response).to redirect_to(account_url)
    end

    context 'renders partials' do
      render_views
      it 'renders show if the user has an invalid sp in the active session' do
        user = create(:user)
        stub_sign_in(user)
        subject.session[:sp] = { issuer: 'awesome sp', ial2: false }
        get :show

        expect(response).to render_template(:show)
        expect(response).to render_template(partial: 'sign_up/completions/_show_identities')
      end

      it 'renders show if the user has identities and no active session' do
        user = create(:user)
        sp = create(:service_provider, issuer: 'https://awesome')
        stub_sign_in(user)
        subject.session[:sp] = { issuer: sp.issuer, ial2: false, requested_attributes: [:email] }
        get :show

        expect(response).to render_template(:show)
        expect(response).to render_template(partial: 'sign_up/completions/_show_sp')
      end
    end
  end

  describe '#update' do
    let(:now) { Time.zone.now }

    before do
      stub_analytics
      allow(@analytics).to receive(:track_event)
      @linker = instance_double(IdentityLinker)
      allow(@linker).to receive(:link_identity).and_return(true)
      allow(IdentityLinker).to receive(:new).and_return(@linker)
    end

    context 'IAL1' do
      it 'tracks analytics' do
        stub_sign_in
        subject.session[:sp] = {
          ial2: false,
          issuer: 'foo',
          request_url: 'http://example.com',
        }

        patch :update

        expect(@analytics).to have_received(:track_event).with(
          Analytics::USER_REGISTRATION_COMPLETE,
          ial2: false,
          service_provider_name: subject.decorated_session.sp_name,
          page_occurence: 'agency-page',
        )
      end

      it 'updates verified attributes' do
        stub_sign_in
        subject.session[:sp] = {
          ial: 1,
          request_url: 'http://example.com',
          requested_attributes: ['email'],
        }
        expect(@linker).to receive(:link_identity).with(
          ial: 1,
          verified_attributes: ['email'],
          last_consented_at: now,
          clear_deleted_at: true,
        )
        Timecop.freeze(now) do
          patch :update
        end
      end

      it 'redirects to account page if the session request_url is removed' do
        stub_sign_in
        subject.session[:sp] = {
          ial2: false,
          issuer: 'foo',
        }

        patch :update
        expect(response).to redirect_to account_path
      end
    end

    context 'IAL2' do
      it 'tracks analytics' do
        user = create(:user, profiles: [create(:profile, :verified, :active)])
        stub_sign_in(user)
        subject.session[:sp] = {
          issuer: 'foo',
          ial2: true,
          request_url: 'http://example.com',
        }

        patch :update

        expect(@analytics).to have_received(:track_event).with(
          Analytics::USER_REGISTRATION_COMPLETE,
          ial2: true,
          service_provider_name: subject.decorated_session.sp_name,
          page_occurence: 'agency-page',
        )
      end

      it 'updates verified attributes' do
        user = create(:user, profiles: [create(:profile, :verified, :active)])
        stub_sign_in(user)
        subject.session[:sp] = {
          ial: 2,
          request_url: 'http://example.com',
          requested_attributes: %w[email first_name verified_at],
        }
        expect(@linker).to receive(:link_identity).with(
          ial: 2,
          verified_attributes: %w[email first_name verified_at],
          last_consented_at: now,
          clear_deleted_at: true,
        )
        Timecop.freeze(now) do
          patch :update
        end
      end
    end
  end
end
