require 'rails_helper'

RSpec.describe Users::BackupCodeSetupController, allowed_extra_analytics: [:*] do
  describe 'before_actions' do
    it 'includes appropriate before_actions' do
      expect(subject).to have_actions(
        :before,
        :authenticate_user!,
        :confirm_user_authenticated_for_2fa_setup,
        :apply_secure_headers_override,
        [:confirm_recently_authenticated_2fa, except: ['reminder', 'continue']],
        :validate_internal_referrer?,
      )
    end
  end

  it 'creates backup codes and logs expected events' do
    user = create(:user, :fully_registered)
    stub_sign_in(user)
    analytics = stub_analytics
    stub_attempts_tracker
    allow(controller).to receive(:in_multi_mfa_selection_flow?).and_return(true)

    Funnel::Registration::AddMfa.call(user.id, 'phone', analytics)
    expect(PushNotification::HttpPush).to receive(:deliver).
      with(PushNotification::RecoveryInformationChangedEvent.new(user: user))
    expect(@analytics).to receive(:track_event).
      with('User marked authenticated', { authentication_type: :valid_2fa_confirmation })
    expect(@analytics).to receive(:track_event).
      with('Backup Code Setup Visited', {
        success: true,
        errors: {},
        mfa_method_counts: { phone: 1 },
        pii_like_keypaths: [[:mfa_method_counts, :phone]],
        error_details: nil,
        enabled_mfa_methods_count: 1,
        in_account_creation_flow: false,
      })
    expect(@analytics).to receive(:track_event).
      with('Backup Code Created', {
        enabled_mfa_methods_count: 2,
        in_account_creation_flow: false,
      })
    expect(@irs_attempts_api_tracker).to receive(:track_event).
      with(:mfa_enroll_backup_code, success: true)

    get :index

    expect(response).to render_template('index')
    expect(user.backup_code_configurations.length).to eq BackupCodeGenerator::NUMBER_OF_CODES
  end

  context 'without existing backup codes' do
    let(:user) { create(:user, :fully_registered) }

    it 'does not revoke remembered device' do
      stub_sign_in(user)
      expect(user.remember_device_revoked_at).to eq nil

      freeze_time do
        get :index
        expect(user.reload.remember_device_revoked_at).to eq nil
      end
    end
  end

  context 'with existing backup codes' do
    let(:user) { create(:user, :fully_registered, :with_backup_code) }

    it 'revokes remembered device' do
      stub_sign_in(user)
      allow(controller).to receive(:in_multi_mfa_selection_flow?).and_return(true)

      expect(user.remember_device_revoked_at).to eq nil

      freeze_time do
        get :index
        expect(user.reload.remember_device_revoked_at).to eq Time.zone.now
      end
    end
  end

  it 'deletes backup codes' do
    user = build(:user, :fully_registered, :with_authentication_app, :with_backup_code)
    stub_sign_in(user)
    expect(user.backup_code_configurations.length).to eq 10

    post :delete

    expect(response).to redirect_to(account_two_factor_authentication_path)
    expect(user.backup_code_configurations.length).to eq 0
  end

  it 'deleting backup codes revokes remember device cookies' do
    user = build(:user, :fully_registered, :with_authentication_app, :with_backup_code)
    stub_sign_in(user)
    expect(user.remember_device_revoked_at).to eq nil

    freeze_time do
      post :delete
      expect(user.reload.remember_device_revoked_at).to eq Time.zone.now
    end
  end

  it 'does not deletes backup codes if they are the only mfa' do
    user = build(:user, :with_backup_code)
    stub_sign_in(user)

    post :delete

    expect(response).to redirect_to(account_two_factor_authentication_path)
    expect(user.backup_code_configurations.length).to eq 10
  end

  describe 'multiple MFA handling' do
    let(:mfa_selections) { ['backup_code', 'voice'] }
    before do
      @user = build(:user)
      stub_sign_in(@user)
      controller.user_session[:mfa_selections] = mfa_selections
    end

    context 'when user selects multiple mfas on account creation' do
      it 'redirects to Phone Url Page after page' do
        codes = BackupCodeGenerator.new(@user).create
        controller.user_session[:backup_codes] = codes
        post :continue

        expect(response).to redirect_to(phone_setup_url)
      end
    end

    context 'when user only selects backup code on account creation' do
      let(:mfa_selections) { ['backup_code'] }
      it 'redirects to Suggest 2nd MFA page' do
        codes = BackupCodeGenerator.new(@user).create
        controller.user_session[:backup_codes] = codes
        post :continue
        expect(response).to redirect_to(auth_method_confirmation_url)
      end
    end
  end

  context 'with multiple MFA selection turned off' do
    it 'redirects to account page' do
      user = build(:user, :fully_registered)
      stub_sign_in(user)
      codes = BackupCodeGenerator.new(user).create
      controller.user_session[:backup_codes] = codes
      post :continue
      expect(response).to redirect_to(account_url)
    end
  end

  describe '#refreshed' do
    render_views

    it 'does not 500 when codes have not been generated' do
      user = create(:user, :fully_registered)
      stub_sign_in(user)
      get :refreshed

      expect(response).to redirect_to(backup_code_setup_url)
    end
  end

  context 'user visits the Backup codes regenerate page' do
    let(:user) { create(:user) }
    before do
      stub_sign_in(user)
      stub_analytics
    end
    it 'renders the index view' do
      get :edit
      expect(@analytics).to have_logged_event(
        'Backup Code Regenerate Visited',
        hash_including(in_account_creation_flow: false),
      )
    end
  end

  context 'invalid referrer to create Backup codes page' do
    it 'redirects to site root' do
      user = create(:user, :fully_registered)
      stub_sign_in(user)
      get :index
      expect(response).to redirect_to(root_url)
    end
  end
end
