require 'rails_helper'

RSpec.describe 'Inherited Proofing VA API Proofer Service' do
  subject(:form) { Idv::InheritedProofing::Va::Form.new(payload_hash: proofer_results) }

  let(:proofer_results) do
    Idv::InheritedProofing::Va::Mocks::Service.new({ auth_code: auth_code }).execute
  end
  let(:auth_code) { Idv::InheritedProofing::Va::Mocks::Service::VALID_AUTH_CODE }

  context 'when used with the VA Inherited Proofing Response Form' do
    it 'works as expected' do
      expect(form.submit.success?).to eq true
    end
  end
end
