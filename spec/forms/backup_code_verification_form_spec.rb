require 'rails_helper'

RSpec.describe BackupCodeVerificationForm do
  subject(:result) { described_class.new(user).submit(params).to_h }

  let(:user) { create(:user) }
  let(:backup_codes) { BackupCodeGenerator.new(user).create }
  let(:backup_code_config) do
    BackupCodeConfiguration.find_with_code(code: code, user_id: user.id)
  end

  describe '#submit' do
    let(:params) do
      {
        backup_code: code,
      }
    end

    context 'with a valid backup code' do
      let(:code) { backup_codes.first }
      let(:expected_response) do
        {
          success: true,
          errors: {},
          multi_factor_auth_method: 'backup_code',
          multi_factor_auth_method_created_at: backup_code_config.created_at.strftime('%s%L'),
        }
      end

      it 'returns succcess' do
        expect(result).to eq(expected_response)
      end

      it 'marks code as used' do
        expect { subject }.to change {
                                backup_code_config.reload.used_at
                              }.from(nil).to kind_of(Time)
      end
    end

    context 'with an invalid backup code' do
      let(:code) { 'invalid' }
      let(:expected_response) do
        {
          success: false,
          errors: {},
          multi_factor_auth_method: 'backup_code',
          multi_factor_auth_method_created_at: nil,
        }
      end

      it 'returns failure' do
        expect(result).to eq(expected_response)
      end
    end
  end
end
