class ProfileProofingComponentsBackfillJob < ApplicationJob
  queue_as :long_running

  def perform
    Profile.where("proofing_components->'id' IS NULL").find_in_batches do |batch|
      updated_count = 0

      batch.each do |profile|
        did_update = update_profile(profile)
        updated_count += 1 if did_update
      end

      Rails.logger.info(
        {
          name: 'profile_proofing_components_update_batch',
          batch_size: batch.size,
          batch_updated: updated_count,
          batch_start: batch.first.id,
          batch_end: batch.last.id,
        }.to_json,
      )
    end
  end

  # @return [Boolean]
  def update_profile(profile)
    profile.proofing_components = profile.proofing_components
    if profile.proofing_components_changed?
      profile.save!
      true
    end
  end
end
