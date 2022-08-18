require 'rails_helper'

describe Idv::Steps::Ipp::SsnStep do
  let(:ssn) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn] }
  let(:params) { { doc_auth: { ssn: ssn } } }
  let(:session) { { sp: { issuer: service_provider.issuer } } }
  let(:user) { build(:user) }
  let(:service_provider) { create(:service_provider) }
  let(:controller) do
    instance_double(
      'controller',
      session: session,
      params: params,
      current_user: user,
    )
  end

  let(:flow) do
    Idv::Flows::InPersonFlow.new(controller, {}, 'idv/in_person')
  end

  subject(:step) do
    Idv::Steps::Ipp::SsnStep.new(flow)
  end

  describe '#call' do
    it 'merges ssn into pii session value' do
      step.call

      expect(flow.flow_session[:pii_from_user][:ssn]).to eq(ssn)
    end

    context 'with existing session applicant' do
      let(:session) { super().merge(idv: { 'applicant' => {} }) }

      it 'clears applicant' do
        step.call

        expect(session[:idv]['applicant']).to be_blank
      end
    end
  end
end
