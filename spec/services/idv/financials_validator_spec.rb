require 'rails_helper'

describe Idv::FinancialsValidator do
  let(:user) { build(:user) }

  let(:applicant) { Proofer::Applicant.new({}) }
  let(:vendor) { :mock }
  let(:vendor_session_id) { SecureRandom.uuid }

  let(:params) do
    { ccn: '123-45-6789' }
  end

  let(:confirmation) { instance_double(Proofer::Confirmation) }

  subject do
    Idv::FinancialsValidator.new(
      applicant: applicant,
      vendor: vendor,
      vendor_params: params,
      vendor_session_id: vendor_session_id
    )
  end

  def stub_agent_calls
    agent = instance_double(Idv::Agent)
    allow(Idv::Agent).to receive(:new).
      with(applicant: applicant, vendor: vendor).
      and_return(agent)
    expect(agent).to receive(:submit_financials).
      with(params, vendor_session_id).and_return(confirmation)
  end

  describe '#result' do
    it 'has success' do
      stub_agent_calls

      success_string = 'true'
      expect(confirmation).to receive(:success?).and_return(success_string)

      expect(subject.result.success?).to eq success_string
    end

    it 'has errors' do
      stub_agent_calls

      error_string = 'mucho errors'

      expect(confirmation).to receive(:errors).and_return(error_string)

      expect(subject.result.errors).to eq error_string
    end
  end
end
