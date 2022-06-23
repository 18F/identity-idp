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

  let(:flow) do
    Idv::Flows::InPersonFlow.new(controller, {}, 'idv/in_person')
  end

  subject(:step) do
    Idv::Steps::Ipp::VerifyStep.new(flow)
  end

  describe '#call' do
    it 'works' do
      step.call
    end
  end
end
