require 'rails_helper'

describe Idv::FinanceJob do
  describe '#perform' do
    let(:result_id) { SecureRandom.uuid }
    let(:applicant_json) { { first_name: 'Jean-Luc', last_name: 'Picard' }.to_json }
    let(:vendor_params) { { ccn: '12345678' } }
    let(:vendor_session_id) { SecureRandom.uuid }

    context 'when verification succeeds' do
      it 'should save a successful result' do
        Idv::FinanceJob.perform_now(
          result_id: result_id,
          vendor: :mock,
          vendor_params: vendor_params,
          applicant_json: applicant_json,
          vendor_session_id: vendor_session_id
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
      let(:vendor_params) { { ccn: '00000000' } }

      it 'should save an unsuccessful result' do
        Idv::FinanceJob.perform_now(
          result_id: result_id,
          vendor: :mock,
          vendor_params: vendor_params,
          applicant_json: applicant_json,
          vendor_session_id: vendor_session_id
        )
        result = VendorValidatorResultStorage.new.load(result_id)

        expect(result.success?).to eq(false)
        expect(result.timed_out?).to eq(false)
        expect(result.job_failed?).to eq(false)
        expect(result.reasons).to eq(['Bad number'])
        expect(result.errors).to eq(ccn: 'The ccn could not be verified.')
      end
    end

    context 'when the idv agent raises' do
      before do
        agent = instance_double(Idv::Agent)
        allow(agent).to receive(:submit_financials).and_raise(RuntimeError, '🔥🔥🔥')
        allow(Idv::Agent).to receive(:new).and_return(agent)
      end

      it 'should rescue from errors and save a failed job result' do
        expect do
          Idv::FinanceJob.perform_now(
            result_id: result_id,
            vendor: :mock,
            vendor_params: vendor_params,
            applicant_json: applicant_json,
            vendor_session_id: vendor_session_id
          )
        end.to raise_error(RuntimeError, '🔥🔥🔥')
        result = VendorValidatorResultStorage.new.load(result_id)

        expect(result.success?).to eq(false)
        expect(result.timed_out?).to eq(false)
        expect(result.job_failed?).to eq(true)
      end
    end
  end
end
