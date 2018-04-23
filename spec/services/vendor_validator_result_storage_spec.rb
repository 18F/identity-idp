require 'rails_helper'

RSpec.describe VendorValidatorResultStorage do
  subject(:service) { VendorValidatorResultStorage.new }

  let(:result_id) { SecureRandom.uuid }
  let(:original_result) do
    Idv::VendorResult.new(
      success: false,
      normalized_applicant: Proofer::Applicant.new(first_name: 'First')
    )
  end

  describe '#store_result' do
    it 'stores the result in redis with a TTL' do
      key = service.redis_key(result_id)

      before_redis = Sidekiq.redis { |redis| redis.get(key) }
      expect(before_redis).to be_nil

      service.store(result_id: result_id, result: original_result)

      Sidekiq.redis do |redis|
        expect(redis.get(key)).to be_present
        expect(redis.ttl(key)).to be_within(1).of(VendorValidatorResultStorage::TTL)
      end
    end
  end

  describe '#vendor_validator_result' do
    before { service.store(result_id: result_id, result: original_result) }

    it 'retrieves a stored result' do
      result = service.load(result_id)

      expect(result.success?).to eq(original_result.success?)
      expect(result.errors).to eq(original_result.errors)
      expect(result.reasons).to eq(original_result.reasons)
      expect(result.normalized_applicant.as_json).
        to eq(original_result.normalized_applicant.as_json)
    end

    it 'is nil with a bad result id' do
      result = service.load(SecureRandom.uuid)

      expect(result).to be_nil
    end
  end
end
