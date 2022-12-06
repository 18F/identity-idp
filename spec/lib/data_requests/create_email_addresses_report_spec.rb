require 'rails_helper'

describe DataRequests::CreateEmailAddressesReport do
  describe '#call' do
    it 'returns an array with hashes representing the users email addresses' do
      user = create(:user)
      email_address = user.email_addresses.first

      result = described_class.new(user).call

      expect(result.length).to eq(1)

      expect(result.first[:email]).to eq(email_address.email)
      expect(result.first[:created_at]).to be_within(1.second).of(
        email_address.created_at,
      )
      expect(result.first[:confirmed_at]).to be_within(1.second).of(
        email_address.confirmed_at,
      )
    end
  end
end
