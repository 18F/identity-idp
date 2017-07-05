require 'rails_helper'

RSpec.describe VendorValidatorJob do
  let(:result_id) { SecureRandom.uuid }
  let(:vendor_validator_class) { 'Idv::PhoneValidator' }
  let(:vendor) { :mock }
  let(:vendor_params) { '+1 (888) 123-4567' }
  let(:applicant) { Proofer::Applicant.new(first_name: 'Test') }
  let(:applicant_json) { applicant.to_json }
  let(:vendor_session_id) { SecureRandom.uuid }

  subject(:job) { VendorValidatorJob.new }

  describe '#perform' do
    subject(:perform) do
      job.perform(
        result_id: result_id,
        vendor_validator_class: vendor_validator_class,
        vendor: vendor,
        vendor_params: vendor_params,
        applicant_json: applicant_json,
        vendor_session_id: vendor_session_id
      )
    end

    it 'calls out to a vendor and serializes the result' do
      expect(Idv::PhoneValidator).to receive(:new).
        with(
          applicant: kind_of(Proofer::Applicant),
          vendor: vendor,
          vendor_params: vendor_params,
          vendor_session_id: vendor_session_id
        ).and_call_original

      before_result = VendorValidatorResultStorage.new.load(result_id)
      expect(before_result).to be_nil

      perform

      after_result = VendorValidatorResultStorage.new.load(result_id)
      expect(after_result).to be_a(Idv::VendorResult)
    end
  end
end
