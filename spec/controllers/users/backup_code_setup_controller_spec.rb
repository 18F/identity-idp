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
    user = create(:user, :signed_up)
    stub_sign_in(user)
    expect(PushNotification::HttpPush).to receive(:deliver).
      with(PushNotification::RecoveryInformationChangedEvent.new(user: user))
    post :create

    expect(response).to render_template('create')
    expect(user.backup_code_configurations.length).to eq BackupCodeGenerator::NUMBER_OF_CODES
  end

  it 'deletes backup codes' do
    user = create(:user, :signed_up)
    stub_sign_in(user)
    expect(PushNotification::HttpPush).to receive(:deliver).
      with(PushNotification::RecoveryInformationChangedEvent.new(user: user))
    post :delete

    expect(response).to redirect_to(account_two_factor_authentication_path)
    expect(user.backup_code_configurations.length).to eq 0
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
