require 'rails_helper'

RSpec.describe SignInABTestConcern, type: :controller do
  controller ApplicationController do
    include SignInABTestConcern
  end

  describe '#sign_in_a_b_test_bucket' do
    subject(:sign_in_a_b_test_bucket) { controller.sign_in_a_b_test_bucket }

    let(:sp_session) { {} }

    before do
      allow(session).to receive(:id).and_return('session-id')
      allow(controller).to receive(:sp_session).and_return(sp_session)
      allow(AbTests::SIGN_IN).to receive(:bucket) do |discriminator|
        case discriminator
        when 'session-id'
          :default
        when 'request-id'
          :tabbed
        end
      end
    end

    it 'returns the bucket based on session id' do
      expect(sign_in_a_b_test_bucket).to eq(:default)
    end

    context 'with associated sp session request id' do
      let(:sp_session) { { request_id: 'request-id' } }

      it 'returns the bucket based on request id' do
        expect(sign_in_a_b_test_bucket).to eq(:tabbed)
      end
    end
  end
end
