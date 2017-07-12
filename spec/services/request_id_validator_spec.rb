require 'rails_helper'

RSpec.describe RequestIdValidator do
  subject(:validator) { RequestIdValidator.new(request_id) }

  describe '#submit' do
    subject(:result) { validator.submit }

    context 'with a blank request_id' do
      let(:request_id) { '' }

      it 'is successful' do
        expect(result.success?).to eq(true)
        expect(result.errors).to be_blank
        expect(result.extra[:request_id]).to eq('')
      end
    end

    context 'with a good request_id' do
      let(:request_id) { create(:service_provider_request).uuid }

      it 'is successful' do
        expect(result.success?).to eq(true)
        expect(result.errors).to be_blank
        expect(result.extra[:request_id]).to eq(request_id)
      end
    end

    context 'with a bad request_id' do
      let(:request_id) { SecureRandom.uuid }

      it 'is unsuccesful' do
        expect(result.success?).to eq(false)
        expect(result.errors[:request_id]).to eq(['is invalid'])
        expect(result.extra[:request_id]).to eq(request_id)
      end
    end
  end
end
