require 'rails_helper'

describe Users::BackupCodeSetupController do
  it 'creates backup codes and logs expected events' do
    user = create(:user, :signed_up)
    stub_sign_in(user)
    analytics = stub_analytics
    stub_attempts_tracker

    Funnel::Registration::AddMfa.call(user.id, 'phone', analytics)
    expect(PushNotification::HttpPush).to receive(:deliver).
      with(PushNotification::RecoveryInformationChangedEvent.new(user: user))
    expect(@analytics).to receive(:track_event).
      with('Backup Code Setup Visited', {
        success: true,
        errors: {},
        mfa_method_counts: { phone: 1 },
        pii_like_keypaths: [[:mfa_method_counts, :phone]],
        error_details: nil,
        enabled_mfa_methods_count: 1,
      })
    expect(@analytics).to receive(:track_event).
      with('Backup Code Created', {
        enabled_mfa_methods_count: 2,
      })
    expect(@irs_attempts_api_tracker).to receive(:track_event).
      with(:mfa_enroll_backup_code, success: true)

    post :create

    expect(response).to render_template('create')
    expect(user.backup_code_configurations.length).to eq BackupCodeGenerator::NUMBER_OF_CODES
  end

  it 'deletes backup codes' do
    user = build(:user, :signed_up, :with_authentication_app, :with_backup_code)
    stub_sign_in(user)
    expect(user.backup_code_configurations.length).to eq 10

    post :delete

    expect(response).to redirect_to(account_two_factor_authentication_path)
    expect(user.backup_code_configurations.length).to eq 0
  end

  it 'does not deletes backup codes if they are the only mfa' do
    user = build(:user, :with_backup_code)
    stub_sign_in(user)

    post :delete

    expect(response).to redirect_to(account_two_factor_authentication_path)
    expect(user.backup_code_configurations.length).to eq 10
  end

  context 'with multiple MFA selection on' do
    let(:mfa_selections) { ['backup_code', 'voice'] }
    before do
      @user = build(:user)
      stub_sign_in(@user)
      controller.user_session[:mfa_selections] = mfa_selections
      allow(IdentityConfig.store).to receive(:select_multiple_mfa_options).and_return true
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
      user = build(:user, :signed_up)
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
      user = create(:user, :signed_up)
      stub_sign_in(user)
      get :refreshed

      expect(response).to redirect_to(backup_code_setup_url)
    end
  end
end
