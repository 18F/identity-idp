require 'rails_helper'

RSpec.describe DuplicateProfile, type: :model do
  let(:service_provider) { create(:service_provider, issuer: 'test-sp') }
  let(:profile_id) { 123 }
  let(:other_profile_id) { 456 }
  let!(:matching_profile) do
    create(
      :duplicate_profile, service_provider: service_provider.issuer,
                          profile_ids: [profile_id, other_profile_id]
    )
  end
  let!(:non_matching_service) do
    create(
      :duplicate_profile, service_provider: 'other-sp',
                          profile_ids: [profile_id, other_profile_id]
    )
  end
  let!(:non_matching_profile) do
    create(:duplicate_profile, service_provider: service_provider.issuer, profile_ids: [999, 888])
  end

  it 'returns records matching both service_provider and profile_id' do
    result = described_class.involving_profile(
      profile_id: profile_id,
      service_provider: service_provider.issuer,
    )

    expect(result).to include(matching_profile)
    expect(result).not_to include(non_matching_service)
    expect(result).not_to include(non_matching_profile)
  end

  it 'returns records when profile_id is anywhere in the profile_ids array' do
    result = described_class.involving_profile(
      profile_id: other_profile_id,
      service_provider: service_provider.issuer,
    )

    expect(result).to include(matching_profile)
  end

  it 'returns empty result when profile_id is not in any profile_ids array' do
    result = described_class.involving_profile(
      profile_id: 777,
      service_provider: service_provider.issuer,
    )

    expect(result).to be_empty
  end
end
