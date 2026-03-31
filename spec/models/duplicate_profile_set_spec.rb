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
    result = described_class.involving_profile(
      profile_id: profile_id,
      service_provider: service_provider.issuer,
    )

    expect(result).to eq(matching_profile)
    expect(result).not_to eq(non_matching_service)
    expect(result).not_to eq(non_matching_profile)
  end

  it 'returns nil result when profile_id is not duplicate profile' do
    result = described_class.involving_profile(
      profile_id: 777,
      service_provider: service_provider.issuer,
    )

    expect(result).to eq(nil)
  end

  describe '.involving_profile_any_sp' do
    let!(:cross_sp_set) do
      create(
        :duplicate_profile_set, service_provider: nil,
                                profile_ids: [profile_id, other_profile_id]
      )
    end

    it 'returns an open set with null service_provider involving the profile' do
      result = described_class.involving_profile_any_sp(profile_id: profile_id)

      expect(result).to eq(cross_sp_set)
    end

    it 'does not return SP-scoped sets' do
      cross_sp_set.destroy!

      result = described_class.involving_profile_any_sp(profile_id: profile_id)

      expect(result).to be_nil
    end

    it 'returns nil when no open set involves the profile' do
      result = described_class.involving_profile_any_sp(profile_id: 777)

      expect(result).to be_nil
    end

    it 'excludes closed sets' do
      cross_sp_set.update!(closed_at: Time.zone.now)

      result = described_class.involving_profile_any_sp(profile_id: profile_id)

      expect(result).to be_nil
    end
  end

  describe '.set_for_profiles' do
    let!(:cross_sp_set) do
      create(
        :duplicate_profile_set, service_provider: nil,
                                profile_ids: [profile_id, other_profile_id]
      )
    end

    it 'returns a null-SP set with overlapping profile_ids' do
      result = described_class.set_for_profiles(profile_ids: [profile_id])

      expect(result).to eq(cross_sp_set)
    end

    it 'does not return SP-scoped sets' do
      cross_sp_set.destroy!

      result = described_class.set_for_profiles(profile_ids: [profile_id])

      expect(result).to be_nil
    end

    it 'returns nil when no set has overlapping profile_ids' do
      result = described_class.set_for_profiles(profile_ids: [111])

      expect(result).to be_nil
    end
  end
end
