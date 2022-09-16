require 'rails_helper'

describe Idv::Steps::InheritedProofing::AgreementStep do
  let(:submitted_values) { {} }
  let(:params) { { consent_form_params: submitted_values } }
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
    Idv::Flows::InheritedProofingFlow.new(controller, {}, 'idv/in_person')
  end

  subject(:step) do
    Idv::Steps::InheritedProofing::AgreementStep.new(flow)
  end

  describe '#call' do
    it 'does nothing' do
      # to be implemented
    end
  end
end
