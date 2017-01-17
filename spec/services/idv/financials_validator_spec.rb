require 'rails_helper'

describe Idv::FinancialsValidator do
  let(:user) { build(:user) }

  let(:idv_session) do
    idvs = Idv::Session.new({}, user)
    idvs.vendor = :mock
    idvs.resolution = Proofer::Resolution.new session_id: 'some-id'
    idvs
  end

  let(:session_id) { idv_session.resolution.session_id }

  let(:params) do
    { ccn: '123-45-6789' }
  end

  let(:confirmation) { instance_double(Proofer::Confirmation) }

  subject { Idv::FinancialsValidator.new(idv_session: idv_session, vendor_params: params) }

  def stub_agent_calls
    agent = instance_double(Idv::Agent)
    allow(Idv::Agent).to receive(:new).
      with(applicant: idv_session.applicant, vendor: :mock).
      and_return(agent)
    expect(agent).to receive(:submit_financials).
      with(params, idv_session.resolution.session_id).and_return(confirmation)
  end

  describe '#success?' do
    it 'returns Proofer::Confirmation#success?' do
      stub_agent_calls

      success_string = 'true'

      expect(confirmation).to receive(:success?).and_return(success_string)

      expect(subject.success?).to eq success_string
    end
  end

  describe '#error' do
    it 'returns Proofer::Confirmation#errors' do
      stub_agent_calls

      error_string = 'mucho errors'

      expect(confirmation).to receive(:errors).and_return(error_string)

      expect(subject.errors).to eq error_string
    end
  end
end
