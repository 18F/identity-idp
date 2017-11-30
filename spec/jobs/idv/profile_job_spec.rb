require 'rails_helper'

describe Idv::ProfileJob do
  describe '#perform' do
    let(:result_id) { SecureRandom.uuid }
    let(:applicant_json) { { first_name: 'Jean-Luc', last_name: 'Picard' }.to_json }
    let(:vendor_params) { { dob: '07/13/2035' } }

    context 'when verification succeeds' do
      it 'should save a successful result' do
        Idv::ProfileJob.perform_now(
          result_id: result_id,
          vendor: :mock,
          vendor_params: vendor_params,
          applicant_json: applicant_json
        )
        result = VendorValidatorResultStorage.new.load(result_id)

        expect(result.success?).to eq(true)
        expect(result.timed_out?).to eq(false)
        expect(result.job_failed?).to eq(false)
        expect(result.normalized_applicant.first_name).to eq('JEAN-LUC')
        expect(result.normalized_applicant.last_name).to eq('PICARD')
        expect(result.reasons).to eq(['Everything looks good'])
        expect(result.errors).to eq({})
        expect(result.session_id).to be_present
      end
    end

    context 'when verification fails' do
      let(:applicant_json) { { first_name: 'Bad', last_name: 'McBadson' }.to_json }

      it 'should save an unsuccessful result' do
        Idv::ProfileJob.perform_now(
          result_id: result_id,
          vendor: :mock,
          vendor_params: vendor_params,
          applicant_json: applicant_json
        )
        result = VendorValidatorResultStorage.new.load(result_id)

        expect(result.success?).to eq(false)
        expect(result.timed_out?).to eq(false)
        expect(result.job_failed?).to eq(false)
        expect(result.reasons).to eq(['The name was suspicious'])
        expect(result.errors).to eq(first_name: 'Unverified first name.')
        expect(result.session_id).to be_present
      end
    end

    context 'when the idv agent raises' do
      before do
        agent = instance_double(Idv::Agent)
        allow(agent).to receive(:start).and_raise(RuntimeError, '🔥🔥🔥')
        allow(Idv::Agent).to receive(:new).and_return(agent)
      end

      it 'should rescue from errors and save a failed job result' do
        expect do
          Idv::ProfileJob.perform_now(
            result_id: result_id,
            vendor: :mock,
            vendor_params: vendor_params,
            applicant_json: applicant_json
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
