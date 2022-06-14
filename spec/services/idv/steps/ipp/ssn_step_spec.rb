require 'rails_helper'

describe Idv::Steps::Ipp::SsnStep do
  let(:params) { { doc_auth: {} } }
  let(:user) { build(:user) }
  let(:service_provider) { create(:service_provider) }
  let(:controller) do
    instance_double(
      'controller',
      session: { sp: { issuer: service_provider.issuer } },
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
    it 'works' do
      result = step.call
      expect(result).to be_nil
    end
  end
end
