require 'rails_helper'

describe 'backup code Generation' do
  it 'should generate backup codes ans be able to verify them' do
    user = create(:user)
    rcg = BackupCodeGenerator.new(user)
    codes = rcg.create

    codes.each do |code|
      success = rcg.verify code
      expect(success).to eq(true)
    end
  end

  it 'should reject invalid codes' do
    user = create(:user)
    rcg = BackupCodeGenerator.new(user)
    rcg.generate

    success = rcg.verify 'This is a string which will never result from code generation'
    expect(success).to be_falsy
  end
end
