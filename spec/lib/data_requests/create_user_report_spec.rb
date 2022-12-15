require 'rails_helper'

describe DataRequests::CreateUserReport do
  it 'returns a report containing information about' do
    user = create(:user)

    result = described_class.new(user).call

    expect(result[:user_id]).to eq(user.id)
    expect(result[:login_uuid]).to eq(user.uuid)
    expect(result[:requesting_issuer_uuid]).to eq(user.uuid)
    expect(result[:email_addresses]).to be_a(Array)
    expect(result[:mfa_configurations]).to be_a(Hash)
    expect(result[:user_events]).to be_a(Array)
  end

  context 'with a requesting SP issuer provided' do
    it 'includes the UUID for a SP if one exists' do
      user = create(:user)
      service_provider = create(:service_provider)
      identity = create(
        :service_provider_identity, user: user, service_provider: service_provider.issuer
      )
      AgencyIdentity.create!(user: user, agency: service_provider.agency, uuid: identity.uuid)

      result = described_class.new(user, service_provider.issuer).call

      expect(result[:user_id]).to eq(user.id)
      expect(result[:login_uuid]).to eq(user.uuid)
      expect(result[:requesting_issuer_uuid]).to eq(identity.uuid)
    end

    it 'includes the ID of the user if the user is not associated with the agency' do
      user = create(:user)

      result = described_class.new(user, 'test123').call

      expect(result[:user_id]).to eq(user.id)
      expect(result[:login_uuid]).to eq(user.uuid)
      expect(result[:requesting_issuer_uuid]).to eq("NonSPUser##{user.id}")
    end
  end
end
