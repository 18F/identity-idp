require 'rails_helper'

describe Idv::Agent do
end
  # TODO
  # context 'profile job' do
  #   describe '#perform' do
  #     let(:result_id) { SecureRandom.uuid }
  #     let(:applicant) { {
  #       first_name: 'Jean-Luc',
  #       last_name: 'Picard',
  #       dob: '07/13/2035',
  #       state: 'VA',
  #       state_id_number: '123456789',
  #       state_id_type: 'drivers_license'
  #     } }

  #     let(:applicant_json) { applicant.to_json }

  #     it 'uses the state vendor params as the state id jurisdiction' do
  #       agent = Idv::Agent.new(applicant: {})
  #       allow(Idv::Agent).to receive(:new).and_return(agent).twice

  #       expect(agent).to receive(:proof).
  #         with(hash_including(state_id_jurisdiction: 'WA')).
  #         and_call_original

  #       Idv::ProoferJob.perform_now(
  #         result_id: result_id,
  #         applicant_json: applicant_json,
  #         stages: %i[profile state_id]
  #       )
  #       result = VendorValidatorResultStorage.new.load(result_id)

  #       expect(result).to be_a(Idv::VendorResult)
  #       expect(result.success?).to eq(true)
  #     end

  #     it 'selects the vendors based on the config' do
  #       mock_proofer_job_agent(config: :profile_proofing_vendor, vendor: 'fancy_vendor')
  #       mock_proofer_job_agent(config: :state_id_proofing_vendor, vendor: 'fancier_vendor')

  #       Idv::ProoferJob.perform_now(
  #         result_id: result_id,
  #         applicant_json: applicant_json,
  #         stages: %i[profile state_id].to_json
  #       )
  #       result = VendorValidatorResultStorage.new.load(result_id)

  #       expect(Idv::Agent).to have_received(:new)
  #       expect(result).to be_a(Idv::VendorResult)
  #     end
  #   end
  # end
