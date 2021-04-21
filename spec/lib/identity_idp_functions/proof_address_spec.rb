require 'rails_helper'
require 'identity_idp_functions/proof_address'

RSpec.describe IdentityIdpFunctions::ProofAddress do
  let(:logger) { Logger.new('/dev/null') }
  let(:trace_id) { SecureRandom.uuid }
  let(:conversation_id) { SecureRandom.hex }
  let(:applicant_pii) do
    {
      first_name: 'Johnny',
      last_name: 'Appleseed',
      uuid: SecureRandom.hex,
      dob: '01/01/1970',
      ssn: '123456789',
      phone: '18888675309',
    }
  end

  describe '#proof' do
    before do
      stub_request(
        :post,
        'https://lexisnexis.example.com/restws/identity/v2/abc123/aaa/conversation',
      ).to_return(
        body: {
          Status: {
            ConversationId: conversation_id,
            TransactionStatus: 'passed',
          },
        }.to_json,
      )

      allow(AppConfig.env).to receive(:lexisnexis_account_id).and_return('abc123')
      allow(AppConfig.env).to receive(:lexisnexis_request_mode).and_return('aaa')
      allow(AppConfig.env).to receive(:lexisnexis_username).and_return('aaa')
      allow(AppConfig.env).to receive(:lexisnexis_password).and_return('aaa')
      allow(AppConfig.env).to receive(:lexisnexis_base_url).and_return('https://lexisnexis.example.com/')
      allow(AppConfig.env).to receive(:lexisnexis_phone_finder_workflow).and_return('aaa')
    end

    subject(:function) do
      IdentityIdpFunctions::ProofAddress.new(
        applicant_pii: applicant_pii,
        trace_id: trace_id,
        logger: logger,
      )
    end

    it 'runs' do
      result = function.proof

      expect(result).to eq(
        address_result: {
          exception: nil,
          errors: {},
          messages: [],
          success: true,
          timed_out: false,
          transaction_id: conversation_id,
          context: { stages: [
            { address: 'lexisnexis:phone_finder' },
          ] },
        },
      )
    end
  end
end
