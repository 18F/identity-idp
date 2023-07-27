require 'rails_helper'

RSpec.describe BackupCodeVerificationForm do
  let(:form) { described_class.new(user) }
  let(:user) { create(:user, :fully_registered) }
  let(:backup_codes) do
    BackupCodeGenerator.new(user).create
  end
  let(:params) do
    {
      backup_code: code,
    }
  end
  subject(:result) { form.submit(params) }

  describe '#submit' do
    context 'with a valid backup code' do
      let(:code) { backup_codes.first }
      let(:backup_code_config) do
        BackupCodeConfiguration.find_with_code(code: code, user_id: user.id)
      end

      it 'returns succcess' do
        expect(result.success?).to eq(true)
        expect(result.extra[:multi_factor_auth_method]).to eq('backup_code')
        expect(result.extra[:multi_factor_auth_method_created_at]).
          to eq(backup_code_config.created_at)
      end

      it 'marks code as used' do
        subject

        expect(backup_code_config.reload.used_at).not_to eq(nil)
      end
    end

    context 'with an invalid backup code' do
      let(:code) { 'invalid' }

      it 'returns failure' do
        expect(result.success?).to eq(false)
      end
    end
  end
end
