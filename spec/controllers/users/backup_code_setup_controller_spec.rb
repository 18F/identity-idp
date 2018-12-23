require 'rails_helper'

describe Users::BackupCodeSetupController do
  it 'has backup codes available for download' do
    user = build(:user, :signed_up, :with_backup_code)
    stub_sign_in(user)
    BackupCodeGenerator.new(user).create
    get :download

    data = user.backup_code_configurations.map(&:code).join("\n") + "\n"
    expect(response.body).to eq(data)
    expect(response.header['Content-Type']).to eq('text/plain')
  end
end
