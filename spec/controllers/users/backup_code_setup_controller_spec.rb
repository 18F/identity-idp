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
end
