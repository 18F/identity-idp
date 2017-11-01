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

    context 'when the vendor throws an exception' do
      let(:vendor_validator_class) { 'Idv::ProfileValidator' }
      let(:applicant) { Proofer::Applicant.new(first_name: 'Fail') }

      let(:exception_msg) { 'Failed to contact proofing vendor' }

      it 'notifies NewRelic and does not raise' do
        expect(NewRelic::Agent).to receive(:notice_error).
          with(kind_of(StandardError))

        perform
      end

      it 'writes a failure result to redis' do
        perform

        result = VendorValidatorResultStorage.new.load(result_id)
        expect(result.success?).to eq(false)
        expect(result.errors).to eq(agent: [exception_msg])
        expect(result.reasons).to eq([exception_msg])
      end
    end

    context 'when parsing the vendor response throws an exception' do
      it 'rescues the error and stores the job failed result' do
        allow(Idv::PhoneValidator).to receive(:new).and_raise(StandardError)

        storage = instance_double(VendorValidatorResultStorage)
        result =  instance_double(Idv::VendorResult, errors: { job_failed: true })
        allow(Idv::VendorResult).to receive(:new).and_return(result)

        expect(VendorValidatorResultStorage).to receive(:new).and_return(storage)
        expect(storage).to receive(:store).with(result_id: result_id, result: result)

        expect { perform }.to raise_error StandardError
      end
    end
  end
end
