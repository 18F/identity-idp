class ProfileProofingComponentsBackfillJob < ApplicationJob
  queue_as :long_running

  def perform
    Profile.find_in_batches do |batch|
      batch.each do |profile|
        update_profile(profile)
      end
    end
  end

  def update_profile(profile)
    profile.proofing_components = profile.proofing_components
    profile.save! if profile.proofing_components_changed?
  end
end
