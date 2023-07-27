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
  let(:result) { form.submit(params) }

  describe '#submit' do
    context 'with a valid backup code' do
      let(:code) { backup_codes.first }

      it 'returns succcess' do
        expect(result.success?).to eq(true)
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
