require 'rails_helper'

describe SignUp::CompletionsController do
  describe '#show' do
    let(:current_sp) { create(:service_provider) }

    context 'user signed in, sp info present' do
      before do
        stub_analytics
        allow(@analytics).to receive(:track_event)
      end

      it 'redirects to account page when SP request URL is not present' do
        user = create(:user)
        stub_sign_in(user)
        subject.session[:sp] = {
          issuer: current_sp.issuer,
        }
        get :show

        expect(response).to redirect_to account_url
      end

      context 'IAL1' do
        it 'tracks page visit' do
          user = create(:user)
          stub_sign_in(user)
          subject.session[:sp] = {
            issuer: current_sp.issuer, ial2: false, requested_attributes: [:email],
            request_url: 'http://localhost:3000'
          }
          get :show

          expect(@analytics).to have_received(:track_event).with(
            'User registration: agency handoff visited',
            ial2: false,
            ialmax: nil,
            service_provider_name: subject.decorated_session.sp_name,
            page_occurence: '',
            needs_completion_screen_reason: :new_sp,
            sp_request_requested_attributes: nil,
            sp_session_requested_attributes: [:email],
          )
        end
      end

      context 'IAL2' do
        let(:user) do
          create(:user, profiles: [create(:profile, :verified, :active)])
        end
        let(:pii) { { ssn: '123456789' } }

        before do
          stub_sign_in(user)
          subject.session[:sp] = {
            issuer: current_sp.issuer, ial2: true, requested_attributes: [:email],
            request_url: 'http://localhost:3000'
          }
          allow(controller).to receive(:user_session).and_return('decrypted_pii' => pii.to_json)
        end

        it 'tracks page visit' do
          get :show

          expect(@analytics).to have_received(:track_event).with(
            'User registration: agency handoff visited',
            ial2: true,
            ialmax: nil,
            service_provider_name: subject.decorated_session.sp_name,
            page_occurence: '',
            needs_completion_screen_reason: :new_sp,
            sp_request_requested_attributes: nil,
            sp_session_requested_attributes: [:email],
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

      it 'renders show if the user has identities and no active session' do
        user = create(:user)
        sp = create(:service_provider, issuer: 'https://awesome')
        stub_sign_in(user)
        subject.session[:sp] = { issuer: sp.issuer, ial2: false, requested_attributes: [:email],
                                 request_url: 'http://localhost:3000' }
        get :show

        expect(response).to render_template(:show)
      end
    end
  end

  describe '#update' do
    let(:now) { Time.zone.now.change(usec: 0) }

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
          'User registration: complete',
          ial2: false,
          ialmax: nil,
          service_provider_name: subject.decorated_session.sp_name,
          page_occurence: 'agency-page',
          needs_completion_screen_reason: :new_sp,
          sp_request_requested_attributes: nil,
          sp_session_requested_attributes: nil,
        )
      end

      it 'updates verified attributes' do
        stub_sign_in
        subject.session[:sp] = {
          issuer: 'foo',
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
        freeze_time do
          travel_to(now)
          patch :update
        end
      end

      it 'redirects to account page if the session request_url is removed' do
        stub_sign_in
        subject.session[:sp] = {
          ial2: false,
          issuer: 'foo',
          requested_attributes: ['email'],
        }

        patch :update
        expect(response).to redirect_to account_path
      end
    end

    context 'IAL2' do
      it 'tracks analytics' do
        user = create(:user, profiles: [create(:profile, :verified, :active)])
        stub_sign_in(user)
        sp = create(:service_provider, issuer: 'https://awesome')
        subject.session[:sp] = {
          issuer: sp.issuer,
          ial2: true,
          request_url: 'http://example.com',
          requested_attributes: ['email'],
        }

        patch :update

        expect(@analytics).to have_received(:track_event).with(
          'User registration: complete',
          ial2: true,
          ialmax: nil,
          service_provider_name: subject.decorated_session.sp_name,
          page_occurence: 'agency-page',
          needs_completion_screen_reason: :new_sp,
          sp_request_requested_attributes: nil,
          sp_session_requested_attributes: ['email'],
        )
      end

      it 'updates verified attributes' do
        user = create(:user, profiles: [create(:profile, :verified, :active)])
        stub_sign_in(user)
        sp = create(:service_provider, issuer: 'https://awesome')
        subject.session[:sp] = {
          issuer: sp.issuer,
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
        allow(Idv::InPerson::CompletionSurveySender).to receive(:send_completion_survey).
          with(user, sp.issuer)
        freeze_time do
          travel_to(now)
          patch :update
        end
      end

      it 'sends the in-person proofing completion survey' do
        user = create(:user, profiles: [create(:profile, :verified, :active)])
        stub_sign_in(user)
        sp = create(:service_provider, issuer: 'https://awesome')
        subject.session[:sp] = {
          issuer: sp.issuer,
          ial: 2,
          request_url: 'http://example.com',
          requested_attributes: %w[email first_name verified_at],
        }
        allow(@linker).to receive(:link_identity).with(
          ial: 2,
          verified_attributes: %w[email first_name verified_at],
          last_consented_at: now,
          clear_deleted_at: true,
        )
        expect(Idv::InPerson::CompletionSurveySender).to receive(:send_completion_survey).
          with(user, sp.issuer)
        freeze_time do
          travel_to(now)
          patch :update
        end
      end
    end
  end
end
