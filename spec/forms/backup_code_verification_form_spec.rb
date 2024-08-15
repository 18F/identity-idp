require 'rails_helper'

RSpec.describe BackupCodeVerificationForm do
  subject(:result) { described_class.new(user).submit(params).to_h }

  let(:user) { create(:user) }
  let(:backup_codes) { BackupCodeGenerator.new(user).delete_and_regenerate }
  let(:backup_code_config) do
    BackupCodeConfiguration.find_with_code(code: code, user_id: user.id)
  end

  describe '#submit' do
    let(:params) { { backup_code: code } }

    context 'with a valid backup code' do
      let(:code) { backup_codes.first }

      it 'returns success' do
        expect(result).to eq(
          success: true,
          multi_factor_auth_method_created_at: backup_code_config.created_at.strftime('%s%L'),
        )
      end

      it 'marks code as used' do
        expect { subject }.
          to change { backup_code_config.reload.used_at }.
          from(nil).
          to kind_of(Time)
      end
    end

    context 'with an invalid backup code' do
      let(:code) { 'invalid' }

      it 'returns failure' do
        expect(result).to eq(
          success: false,
          error_details: { backup_code: { invalid: true } },
          multi_factor_auth_method_created_at: nil,
        )
      end
    end
  end
end
