require 'rails_helper'

RSpec.describe 'Test::NdsPages', type: :request do
  before do
    allow(IdentityConfig.store).to receive(:enable_test_routes).and_return(true)
  end

  describe 'GET /test/nds' do
    it 'renders the index listing every catalog page' do
      get test_nds_path

      expect(response).to have_http_status(:ok)
      Test::NDSPageCatalog.pages.each do |page|
        expect(response.body).to include(page.title)
      end
    end

    it 'hides the identity-level control until a dev session exists' do
      get test_nds_path
      expect(response.body).not_to include('Identity level:')

      post test_nds_seed_session_path
      get test_nds_path
      expect(response.body).to include('Identity level:')
    end
  end

  describe 'GET /test/nds/:page' do
    context 'with the default permutation for every page' do
      it 'renders 200' do
        Test::NDSPageCatalog.pages.each do |page|
          get test_nds_page_path(page: page.key)

          expect(response).to have_http_status(:ok), "expected 200 for #{page.key}"
        end
      end
    end

    context 'with representative permutations' do
      {
        'sign-in' => { sp: '1', error: 'email' },
        'create-account' => { sp_alert: '1', error: 'email' },
        'verify-email' => { resend: '1' },
        'enter-password' => { toast: '1', error: '1' },
        'mfa-setup' => { piv_cac: '1' },
        'otp-entry' => { delivery: 'voice', landline: '1', countdown: '1' },
      }.each do |page_key, params|
        it "renders 200 for #{page_key} with #{params}" do
          get test_nds_page_path(page: page_key, **params)

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'with an unknown page' do
      it 'renders 404' do
        get test_nds_page_path(page: 'does-not-exist')

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  context 'when test routes are disabled' do
    before do
      allow(IdentityConfig.store).to receive(:enable_test_routes).and_return(false)
    end

    it 'renders 404 from the controller guard' do
      get test_nds_path

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /test/nds/seed_session' do
    it 'creates a fully-authenticated dev session so gated pages render' do
      expect { post test_nds_seed_session_path }.to change(User, :count).by(1)
      expect(response).to redirect_to(test_nds_path)

      get account_path
      expect(response).to have_http_status(:ok)
    end

    it 'seeds recent 2FA so reauthentication-gated pages render' do
      post test_nds_seed_session_path

      get '/manage/password'
      expect(response).to have_http_status(:ok)
    end

    it 'reuses the existing dev user on a second seed' do
      post test_nds_seed_session_path
      expect { post test_nds_seed_session_path }.not_to change(User, :count)
    end
  end

  describe 'POST /test/nds/generate_mfa' do
    before { post test_nds_seed_session_path }

    it 'creates records and returns the option catalog' do
      expect { post test_nds_generate_mfa_path }
        .to change(WebauthnConfiguration, :count).by(1)
        .and change(PivCacConfiguration, :count).by(1)
        .and change(AuthAppConfiguration, :count).by(1)
        .and change(Device, :count).by(1)

      body = response.parsed_body
      expect(body['by_template']).to include(
        '/manage/webauthn/:id', '/manage/piv_cac/:id', '/manage/auth_app/:id',
        '/manage/email/confirm_delete/:id', '/account/devices/:id/events',
        '/manage/phone/:id'
      )
      expect(body['by_param']).to include('sp_id', 'identity_id', 'opt_out_uuid', 'source')
    end

    it 'includes synthetic none/invalid choices for each param' do
      post test_nds_generate_mfa_path

      webauthn_options = response.parsed_body.dig('by_template', '/manage/webauthn/:id')
      values = webauthn_options.pluck('value')
      expect(values).to include('', '0')
      expect(webauthn_options.length).to be >= 3
    end

    it 'is idempotent across repeated calls' do
      post test_nds_generate_mfa_path
      webauthn_count = WebauthnConfiguration.count
      device_count = Device.count

      post test_nds_generate_mfa_path

      expect(WebauthnConfiguration.count).to eq(webauthn_count)
      expect(Device.count).to eq(device_count)
    end

    it 'seeds an identity that account/history can sort by happened_at' do
      post test_nds_generate_mfa_path

      get '/account/history'
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /test/nds/record_options' do
    it 'returns the option catalog without creating records' do
      post test_nds_seed_session_path
      post test_nds_generate_mfa_path

      expect { get test_nds_record_options_path }.not_to change(WebauthnConfiguration, :count)
      expect(response.parsed_body['by_template']).to include('/manage/webauthn/:id')
    end

    it 'returns an empty catalog and creates no user when not signed in' do
      expect { get test_nds_record_options_path }.not_to change(User, :count)
      expect(response.parsed_body).to eq('by_template' => {}, 'by_param' => {})
    end
  end

  describe 'POST /test/nds/delete_record' do
    before do
      post test_nds_seed_session_path
      post test_nds_generate_mfa_path
    end

    it 'deletes the identified record and returns the refreshed catalog' do
      webauthn = User.last.webauthn_configurations.first

      expect do
        post test_nds_delete_record_path, params: { param: 'webauthn', id: webauthn.id }
      end.to change(WebauthnConfiguration, :count).by(-1)

      values = response.parsed_body.dig('by_template', '/manage/webauthn/:id').pluck('value')
      expect(values).not_to include(webauthn.id.to_s)
    end

    it 'ignores an unknown param without error' do
      expect do
        post test_nds_delete_record_path, params: { param: 'nope', id: '1' }
      end.not_to change(WebauthnConfiguration, :count)
      expect(response).to have_http_status(:ok)
    end

    it 'handles a stale numeric id for a uuid-less model without error' do
      post test_nds_delete_record_path, params: { param: 'webauthn', id: '999999' }
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /test/nds/seed_state' do
    let(:target) { '/duplicate_profiles_detected' }

    context 'with a seeded dev session' do
      before { post test_nds_seed_session_path }

      it 'seeds state and makes the gated page render' do
        expect { post test_nds_seed_state_path, params: { path: target } }
          .to change(DuplicateProfileSet, :count).by(1)
        expect(response).to redirect_to(target)

        get target
        expect(response).to have_http_status(:ok)
      end

      context 'when global duplicate detection is enabled' do
        before do
          allow(IdentityConfig.store)
            .to receive(:enable_one_account_global_detection).and_return(true)
        end

        it 'seeds a global (SP-null) set so the page still renders' do
          post test_nds_seed_state_path, params: { path: target }
          expect(DuplicateProfileSet.last.service_provider).to be_nil

          get target
          expect(response).to have_http_status(:ok)
        end
      end

      it 'is idempotent across repeated calls' do
        post test_nds_seed_state_path, params: { path: target }
        expect { post test_nds_seed_state_path, params: { path: target } }
          .not_to change(DuplicateProfileSet, :count)
      end

      it 'renders 404 for an unregistered path' do
        post test_nds_seed_state_path, params: { path: '/not/registered' }
        expect(response).to have_http_status(:not_found)
      end

      it 'tears the state back down on reset' do
        post test_nds_seed_state_path, params: { path: target }

        expect { post test_nds_reset_state_path, params: { path: target } }
          .to change(DuplicateProfileSet, :count).to(0)
        expect(response).to redirect_to(test_nds_path)

        get target
        expect(response).to redirect_to(root_url)
      end
    end

    context 'without a signed-in dev user' do
      it 'renders 404' do
        post test_nds_seed_state_path, params: { path: target }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /test/nds/set_identity_level' do
    before { post test_nds_seed_session_path }

    def dev_user
      EmailAddress.find_with_email('nds-explorer-dev@example.com').user
    end

    it 'builds an active verified IAL2 profile' do
      post test_nds_set_identity_level_path, params: { level: 'ial2' }
      expect(response).to redirect_to(test_nds_path)

      profile = dev_user.reload.profiles.find_by(active: true)
      expect(profile).to be_present
      expect(profile.idv_level).to eq('legacy_unsupervised')
    end

    it 'builds a facial-match verified profile' do
      post test_nds_set_identity_level_path, params: { level: 'ial2_facial_match' }
      expect(dev_user.reload.profiles.find_by(active: true).facial_match?).to be(true)
    end

    it 'builds a pending in-person enrollment for the reentrant flow' do
      expect { post test_nds_set_identity_level_path, params: { level: 'in_person_pending' } }
        .to change(InPersonEnrollment, :count).by(1)

      user = dev_user.reload
      expect(user.in_person_enrollments.where(status: :pending)).to be_present
      expect(user.profiles.find_by(active: true)).to be_nil
    end

    it 'seeds an in-person enrollment whose ready_to_verify barcode renders' do
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      post test_nds_set_identity_level_path, params: { level: 'in_person_pending' }

      get '/verify/in_person/ready_to_verify'
      expect(response).to have_http_status(:ok)
    end

    it 'builds a verify-by-mail pending profile' do
      post test_nds_set_identity_level_path, params: { level: 'gpo_pending' }
      expect(dev_user.reload.profiles.where.not(gpo_verification_pending_at: nil)).to be_present
    end

    it 'clears prior state when switching levels' do
      post test_nds_set_identity_level_path, params: { level: 'in_person_pending' }
      post test_nds_set_identity_level_path, params: { level: 'unverified' }

      user = dev_user.reload
      expect(user.profiles).to be_empty
      expect(user.in_person_enrollments).to be_empty
    end

    it 'renders 404 for an unknown level' do
      post test_nds_set_identity_level_path, params: { level: 'bogus' }
      expect(response).to have_http_status(:not_found)
    end

    it 'renders 404 when not signed in' do
      post test_nds_sign_out_path
      post test_nds_set_identity_level_path, params: { level: 'ial2' }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'session-gated page states' do
    before { post test_nds_seed_session_path }

    {
      '/webauthn_setup_mismatch' => WebauthnConfiguration,
      '/login/two_factor/piv_cac_mismatch' => nil,
    }.each do |path, model|
      context "for #{path}" do
        it 'renders 200 after seeding and redirects after reset' do
          post test_nds_seed_state_path, params: { path: }
          expect(response).to redirect_to(path)
          expect(model.count).to be >= 1 if model

          get path
          expect(response).to have_http_status(:ok)

          post test_nds_reset_state_path, params: { path: }
          get path
          expect(response).to have_http_status(:redirect)
        end
      end
    end

    context 'for /account/connected_services' do
      let(:path) { '/account/connected_services' }

      it 'seeds connected identities and clears them on reset' do
        expect { post test_nds_seed_state_path, params: { path: } }
          .to change { ServiceProviderIdentity.where.not(deleted_at: nil).count }
          .by(0)
        expect(response).to redirect_to(path)

        user = EmailAddress.find_with_email('nds-explorer-dev@example.com').user
        expect(user.connected_apps.count).to eq(2)

        get path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('NDS Dev App A', 'NDS Dev App B')

        post test_nds_reset_state_path, params: { path: }
        expect(user.reload.connected_apps.count).to eq(0)
      end

      it 'is idempotent across repeated seeds' do
        post test_nds_seed_state_path, params: { path: }
        user = EmailAddress.find_with_email('nds-explorer-dev@example.com').user
        expect { post test_nds_seed_state_path, params: { path: } }
          .not_to change { user.reload.connected_apps.count }
      end
    end
  end

  describe 'POST /test/nds/sign_out' do
    it 'signs the dev user out' do
      post test_nds_seed_session_path
      post test_nds_sign_out_path
      expect(response).to redirect_to(test_nds_path)

      get account_path
      expect(response).to redirect_to(new_user_session_url)
    end
  end

  describe 'dev-only guards on the seed/generate actions' do
    context 'when test routes are disabled' do
      before do
        allow(IdentityConfig.store).to receive(:enable_test_routes).and_return(false)
      end

      it 'renders 404 without creating records' do
        expect { post test_nds_seed_session_path }.not_to change(User, :count)
        expect(response).to have_http_status(:not_found)

        post test_nds_generate_mfa_path
        expect(response).to have_http_status(:not_found)

        post test_nds_seed_state_path, params: { path: '/duplicate_profiles_detected' }
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when running in a prod-like env' do
      before do
        allow(Rails).to receive(:env)
          .and_return(ActiveSupport::EnvironmentInquirer.new('production'))
      end

      it 'renders 404 and mutates nothing for every seeding/mutating action' do
        aggregate_failures do
          expect { post test_nds_seed_session_path }.not_to change(User, :count)
          expect(response).to have_http_status(:not_found)

          expect { post test_nds_generate_mfa_path }.not_to change(WebauthnConfiguration, :count)
          expect(response).to have_http_status(:not_found)

          post test_nds_delete_record_path, params: { param: 'webauthn', id: '1' }
          expect(response).to have_http_status(:not_found)

          expect do
            post test_nds_seed_state_path, params: { path: '/duplicate_profiles_detected' }
          end.not_to change(DuplicateProfileSet, :count)
          expect(response).to have_http_status(:not_found)

          post test_nds_reset_state_path, params: { path: '/duplicate_profiles_detected' }
          expect(response).to have_http_status(:not_found)

          expect { post test_nds_set_identity_level_path, params: { level: 'ial2' } }
            .not_to change(Profile, :count)
          expect(response).to have_http_status(:not_found)

          get test_nds_record_options_path
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
