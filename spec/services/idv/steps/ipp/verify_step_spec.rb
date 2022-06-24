require 'rails_helper'

describe Idv::Steps::Ipp::VerifyStep do
  let(:user) { build(:user) }
  let(:service_provider) { create(:service_provider) }
  let(:controller) do
    instance_double(
      'controller',
      session: { sp: { issuer: service_provider.issuer } },
      current_user: user,
      url_options: {},
    )
  end

  let(:pii) do
    Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.dup
  end

  let(:flow) do
    Idv::Flows::InPersonFlow.new(controller, {}, 'idv/in_person').tap do |flow|
      flow.flow_session = { pii_from_user: pii }
    end
  end

  subject(:step) do
    Idv::Steps::Ipp::VerifyStep.new(flow)
  end

  describe '#call' do
    it 'moves PII into IDV session' do
      expect(flow.idv_session).to_not have_key 'applicant'
      expect(flow.flow_session).to have_key :pii_from_user
      step.call

      expect(flow.flow_session).to_not have_key :pii_from_user
      expect(flow.idv_session).to have_key 'applicant'
      expect(flow.idv_session['applicant']).to include(pii)
    end
  end
end
