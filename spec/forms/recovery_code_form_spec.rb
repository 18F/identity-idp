require 'rails_helper'

describe RecoveryCodeForm do
  describe '#submit' do
    context 'when the form is valid' do
      it 'returns true for success?' do
        user = create(:user)
        raw_code = RecoveryCodeGenerator.new(user).create

        result = RecoveryCodeForm.new(user, raw_code).submit

        result_hash = {
          success: true
        }

        expect(result).to eq result_hash
        expect(user.recovery_code).to be_nil
      end
    end

    context 'when the form is invalid' do
      it 'returns false for success?' do
        user = build_stubbed(:user, :signed_up)
        RecoveryCodeGenerator.new(user).create

        result = RecoveryCodeForm.new(user, 'foo').submit

        result_hash = {
          success: false
        }

        expect(result).to eq result_hash
        expect(user.recovery_code).to_not be_nil
      end
    end
  end
end
