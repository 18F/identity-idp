require 'rails_helper'

describe Users::BackupCodeSetupController do
  it 'has backup codes available for download' do
    user = build(:user, :signed_up)
    stub_sign_in(user)
    codes = BackupCodeGenerator.new(user).create
    controller.user_session[:backup_codes] = codes
    get :download

    expect(response.body).to eq(codes.join("\r\n") + "\r\n")
    expect(response.header['Content-Type']).to eq('text/plain')
  end

  it 'creates backup codes' do
    user = build(:user, :signed_up)
    stub_sign_in(user)
    expect(PushNotification::HttpPush).to receive(:deliver).
      with(PushNotification::RecoveryInformationChangedEvent.new(user: user))
    post :create

    expect(response).to render_template('create')
    expect(user.backup_code_configurations.length).to eq BackupCodeGenerator::NUMBER_OF_CODES
  end

  it 'deletes backup codes' do
    user = build(:user, :signed_up)
    stub_sign_in(user)
    expect(PushNotification::HttpPush).to receive(:deliver).
      with(PushNotification::RecoveryInformationChangedEvent.new(user: user))
    post :delete

    expect(response).to redirect_to(account_two_factor_authentication_path)
    expect(user.backup_code_configurations.length).to eq 0
  end

  context 'when user selects multiple mfas on account creation' do
    before do
      allow(IdentityConfig.store).to receive(:select_multiple_mfa_options).and_return true
    end

    it 'redirects to MFA confirmation page' do
      user = build(:user, :signed_up)
      stub_sign_in(user)
      codes = BackupCodeGenerator.new(user).create
      controller.user_session[:backup_codes] = codes

      controller.user_session[:selected_mfa_options] = ['backup_code', 'voice']
      post :continue

      expect(response).to redirect_to(auth_method_confirmation_url(next_setup_choice: 'voice'))
    end
  end

  context 'when user only selects backup code on account creation' do
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
