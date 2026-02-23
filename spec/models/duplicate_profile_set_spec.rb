require 'rails_helper'

RSpec.describe DuplicateProfileSet, type: :model do
  let(:service_provider) { create(:service_provider, issuer: 'test-sp') }
  let(:profile_id) { 123 }
  let(:other_profile_id) { 456 }
  let!(:matching_profile) do
    create(
      :duplicate_profile_set, service_provider: service_provider.issuer,
                              profile_ids: [profile_id, other_profile_id]
    )
  end
  let!(:non_matching_service) do
    create(
      :duplicate_profile_set, service_provider: 'other-sp',
                              profile_ids: [profile_id, other_profile_id]
    )
  end
  let!(:non_matching_profile) do
    create(
      :duplicate_profile_set, service_provider: service_provider.issuer,
                              profile_ids: [999, 888]
    )
  end

  it 'returns record matching both service_provider and profile_id' do
    result = DuplicateProfileSet.involving_profile(
      profile_id: profile_id,
      service_provider: service_provider.issuer,
    )

    expect(result).to eq(matching_profile)
    expect(result).not_to eq(non_matching_service)
    expect(result).not_to eq(non_matching_profile)
  end

  it 'returns nil result when profile_id is not duplicate profile' do
    result = DuplicateProfileSet.involving_profile(
      profile_id: 777,
      service_provider: service_provider.issuer,
    )

    expect(result).to eq(nil)
  end
end
