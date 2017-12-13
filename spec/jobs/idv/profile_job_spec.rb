require 'rails_helper'

describe Idv::ProfileJob do
  include ProoferJobHelper

  describe '#perform' do
    let(:result_id) { SecureRandom.uuid }
    let(:applicant_json) { { first_name: 'Jean-Luc', last_name: 'Picard' }.to_json }
    let(:vendor_params) do
      {
        dob: '07/13/2035',
        state: 'VA',
        state_id_number: '123456789',
        state_id_type: 'drivers_license',
      }
    end

    it 'uses the state vendor params as the state id jurisdiction' do
      agent = Idv::Agent.new(vendor: :mock, applicant: {})
      allow(Idv::Agent).to receive(:new).and_return(agent).twice

      expect(agent).to receive(:submit_state_id).
        with(hash_including(state_id_jurisdiction: vendor_params[:state])).
        and_call_original

      Idv::ProfileJob.perform_now(
        result_id: result_id,
        vendor_params: vendor_params,
        applicant_json: applicant_json
      )
      result = VendorValidatorResultStorage.new.load(result_id)

      expect(result).to be_a(Idv::VendorResult)
      expect(result.success?).to eq(true)
    end

    context 'when resolution and state id confirmation succeed' do
      it 'should save a successful result' do
        Idv::ProfileJob.perform_now(
          result_id: result_id,
          vendor_params: vendor_params,
          applicant_json: applicant_json
        )
        result = VendorValidatorResultStorage.new.load(result_id)

        expect(result.success?).to eq(true)
        expect(result.timed_out?).to eq(false)
        expect(result.job_failed?).to eq(false)
        expect(result.normalized_applicant.first_name).to eq('JEAN-LUC')
        expect(result.normalized_applicant.last_name).to eq('PICARD')
        expect(result.reasons).to eq(['Everything looks good', 'valid state ID'])
        expect(result.errors).to eq({})
        expect(result.session_id).to be_present
      end
    end

    context 'when resolution fails' do
      it 'should save an unsuccessful result and not call state id proofer' do
        applicant = Proofer::Applicant.new(first_name: 'Bad')
        agent = Idv::Agent.new(vendor: :mock, applicant: applicant)
        allow(agent).to receive(:start).and_call_original
        allow(agent).to receive(:submit_state_id).and_call_original
        allow(Idv::Agent).to receive(:new).and_return(agent).twice

        Idv::ProfileJob.perform_now(
          result_id: result_id,
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
        expect(agent).to have_received(:start)
        expect(agent).to_not have_received(:submit_state_id)
      end
    end

    context 'when state id confirmation fails' do
      let(:vendor_params) { super().merge(state_id_number: '000000000') }

      it 'saves an unsuccessful result' do
        Idv::ProfileJob.perform_now(
          result_id: result_id,
          vendor_params: vendor_params,
          applicant_json: applicant_json
        )
        result = VendorValidatorResultStorage.new.load(result_id)

        expect(result.success?).to eq(false)
        expect(result.timed_out?).to eq(false)
        expect(result.job_failed?).to eq(false)
        expect(result.reasons).to eq(['Everything looks good', 'invalid state id number'])
        expect(result.errors).to eq(state_id_number: 'The state ID number could not be verified')
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

    it 'selects the vendors based on the config' do
      mock_proofer_job_agent(config: :profile_proofing_vendor, vendor: 'fancy_vendor')
      mock_proofer_job_agent(config: :state_id_proofing_vendor, vendor: 'fancier_vendor')

      Idv::ProfileJob.perform_now(
        result_id: result_id,
        vendor_params: vendor_params,
        applicant_json: applicant_json
      )
      result = VendorValidatorResultStorage.new.load(result_id)

      expect(Idv::Agent).to have_received(:new).with(hash_including(vendor: :fancy_vendor))
      expect(Idv::Agent).to have_received(:new).with(hash_including(vendor: :fancier_vendor))
      expect(result).to be_a(Idv::VendorResult)
    end
  end
end
