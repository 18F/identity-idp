require 'rails_helper'

describe Idv::PhoneJob do
  include ProoferJobHelper

  describe '#perform' do
    let(:result_id) { SecureRandom.uuid }
    let(:applicant_json) { { first_name: 'Jean-Luc', last_name: 'Picard' }.to_json }
    let(:vendor_params) { '5555550000' }

    context 'when verification succeeds' do
      it 'should save a successful result' do
        Idv::PhoneJob.perform_now(
          result_id: result_id,
          vendor_params: vendor_params,
          applicant_json: applicant_json,
        )
        result = VendorValidatorResultStorage.new.load(result_id)

        expect(result.success?).to eq(true)
        expect(result.timed_out?).to eq(false)
        expect(result.job_failed?).to eq(false)
        expect(result.reasons).to eq(['Good number'])
        expect(result.errors).to eq({})
      end
    end

    context 'when verification fails' do
      let(:vendor_params) { '5555555555' }

      it 'should save an unsuccessful result' do
        Idv::PhoneJob.perform_now(
          result_id: result_id,
          vendor_params: vendor_params,
          applicant_json: applicant_json,
        )
        result = VendorValidatorResultStorage.new.load(result_id)

        expect(result.success?).to eq(false)
        expect(result.timed_out?).to eq(false)
        expect(result.job_failed?).to eq(false)
        expect(result.reasons).to eq(['Bad number'])
        expect(result.errors).to eq(phone: 'The phone number could not be verified.')
      end
    end

    context 'when the idv agent raises' do
      before do
        agent = instance_double(Idv::Agent)
        allow(agent).to receive(:submit_phone).and_raise(RuntimeError, '🔥🔥🔥')
        allow(Idv::Agent).to receive(:new).and_return(agent)
      end

      it 'should rescue from errors and save a failed job result' do
        expect do
          Idv::PhoneJob.perform_now(
            result_id: result_id,
            vendor_params: vendor_params,
            applicant_json: applicant_json,
          )
        end.to raise_error(RuntimeError, '🔥🔥🔥')
        result = VendorValidatorResultStorage.new.load(result_id)

        expect(result.success?).to eq(false)
        expect(result.timed_out?).to eq(false)
        expect(result.job_failed?).to eq(true)
      end
    end

    it 'selects the proofer vendor based on the config' do
      mock_proofer_job_agent(config: :phone_proofing_vendor, vendor: 'fancy_vendor')

      Idv::PhoneJob.perform_now(
        result_id: result_id,
        vendor_params: vendor_params,
        applicant_json: applicant_json,
      )
      result = VendorValidatorResultStorage.new.load(result_id)

      expect(Idv::Agent).to have_received(:new).with(hash_including(vendor: :fancy_vendor))
      expect(result).to be_a(Idv::VendorResult)
    end
  end
end
