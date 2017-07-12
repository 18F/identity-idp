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
      end

      it 'reports a blank request_id' do
        expect(result.extra[:request_id_present]).to eq(false)
      end
    end

    context 'with a good request_id' do
      let(:request_id) { create(:service_provider_request).uuid }

      it 'is successful' do
        expect(result.success?).to eq(true)
        expect(result.errors).to be_blank
      end

      it 'reports a present request_id' do
        expect(result.extra[:request_id_present]).to eq(true)
      end
    end

    context 'with a bad request_id' do
      let(:request_id) { SecureRandom.uuid }

      it 'is unsuccesful' do
        expect(result.success?).to eq(false)
        expect(result.errors[:request_id]).to eq(['is invalid'])
      end

      it 'reports a present request_id' do
        expect(result.extra[:request_id_present]).to eq(true)
      end
    end
  end
end
