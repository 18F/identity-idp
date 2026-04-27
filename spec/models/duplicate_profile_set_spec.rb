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

  describe '.set_for_profiles_global' do
    let!(:global_set) do
      create(
        :duplicate_profile_set, :global,
        profile_ids: [profile_id, other_profile_id]
      )
    end

    it 'returns record matching profile_ids with null service_provider' do
      result = described_class.set_for_profiles_global(profile_ids: [profile_id])
      expect(result).to eq(global_set)
    end

    it 'returns nil when no global set overlaps' do
      result = described_class.set_for_profiles_global(profile_ids: [777])
      expect(result).to be_nil
    end

    context 'when SP scoped set overlaps but no global set overlaps' do
      it 'returns nil' do
        global_set.delete
        result = described_class.set_for_profiles_global(profile_ids: [profile_id])
        expect(result).to be_nil
      end
    end
  end

  describe '.involving_profile_global' do
    let!(:global_set) do
      create(
        :duplicate_profile_set, :global,
        profile_ids: [profile_id, other_profile_id]
      )
    end

    it 'returns open global set containing the profile_id' do
      result = described_class.involving_profile_global(profile_id: profile_id)
      expect(result).to eq(global_set)
    end

    it 'does not return closed global sets' do
      global_set.update!(closed_at: Time.zone.now)
      result = described_class.involving_profile_global(profile_id: profile_id)
      expect(result).to be_nil
    end

    it 'returns nil when profile is not in any global set' do
      result = described_class.involving_profile_global(profile_id: 777)
      expect(result).to be_nil
    end

    context 'when SP scoped set overlaps but no global set overlaps' do
      it 'returns nil' do
        global_set.delete
        result = described_class.set_for_profiles_global(profile_ids: [profile_id])
        expect(result).to be_nil
      end
    end
  end

  describe '.close_sp_scoped_sets_for_profile' do
    it 'closes open SP-scoped sets containing the profile' do
      expect(matching_profile.closed_at).to be_nil
      described_class.close_sp_scoped_sets_for_profile(profile_id: profile_id)
      expect(matching_profile.reload.closed_at).not_to be_nil
    end

    it 'closes multiple SP-scoped sets for the same profile' do
      expect(non_matching_service.closed_at).to be_nil
      described_class.close_sp_scoped_sets_for_profile(profile_id: profile_id)
      expect(matching_profile.reload.closed_at).not_to be_nil
      expect(non_matching_service.reload.closed_at).not_to be_nil
      expect(non_matching_profile.reload.closed_at).to be_nil
    end

    it 'does not close global (null SP) sets' do
      global_set = create(
        :duplicate_profile_set, :global,
        profile_ids: [profile_id, other_profile_id]
      )
      described_class.close_sp_scoped_sets_for_profile(profile_id: profile_id)
      expect(global_set.reload.closed_at).to be_nil
    end

    it 'does not close sets that do not contain the profile' do
      described_class.close_sp_scoped_sets_for_profile(profile_id: profile_id)
      expect(non_matching_profile.reload.closed_at).to be_nil
    end
  end
end
