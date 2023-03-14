require 'rails_helper'

RSpec.describe AccountReset::CreateRequest do
  subject(:sp_issuer) { 'example-issuer' }
  subject(:create_request) { described_class.new(user, sp_issuer) }

  describe '#call' do
    context 'when the user does not have a phone' do
      let(:user) { build(:user) }

      it 'does not include a message_id in the response' do
        response = create_request.call

        expect(response.to_h[:message_id]).to be_blank
      end
    end

    context 'when the user has a phone' do
      let(:user) { build(:user, :with_phone) }

      it 'includes a message_id in the response' do
        response = create_request.call

        expect(response.to_h[:message_id]).to be_present
      end
    end

    context 'when sp_issuer is passed' do
      let(:user) { build(:user) }

      it 'it stores sp_issuer' do
        create_request.call
        arr = AccountResetRequest.find_by(user_id: user.id)

        expect(arr.sp_issuer).to eq sp_issuer
      end
    end
  end
end
