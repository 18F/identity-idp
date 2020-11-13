require 'rails_helper'

describe Idv::Steps::VerifyStep do
  let(:user) { build(:user) }
  let(:service_provider) do
    create(:service_provider,
           issuer: 'http://sp.example.com',
           app_id: '123')
  end

  describe '#call' do
    it 'sets uuid_prefix on pii_from_doc' do
      controller = instance_double('controller',
                                   session: { sp: { issuer: service_provider.issuer } },
                                   current_user: user)
      flow = Idv::Flows::DocAuthFlow.new(controller, {}, 'idv/doc_auth')
      flow.flow_session = { pii_from_doc: {} }
      step = Idv::Steps::VerifyStep.new(flow)
      step.call

      expect(flow.flow_session[:pii_from_doc][:uuid_prefix]).to eq service_provider.app_id
    end
  end
end
