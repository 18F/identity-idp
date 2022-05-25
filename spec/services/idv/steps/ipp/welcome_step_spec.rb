require 'rails_helper'

describe Idv::Steps::Ipp::WelcomeStep do
  let(:user) { build(:user) }
  let(:service_provider) { create(:service_provider) }
  let(:controller) do
    instance_double(
      'controller',
      session: { sp: { issuer: service_provider.issuer } },
      current_user: user,
    )
  end

  let(:flow) do
    Idv::Flows::InPersonFlow.new(controller, {}, 'idv/in_person')
  end

  subject(:step) do
    Idv::Steps::Ipp::WelcomeStep.new(flow)
  end

  describe '#call' do
    it 'works' do
      result = step.call
      expect(result).to be_nil
    end
  end
end
