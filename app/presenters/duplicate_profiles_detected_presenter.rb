# frozen_string_literal: true

class DuplicateProfilesDetectedPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :user, :duplicate_profile_set

  def initialize(user:, duplicate_profile_set:)
    @user = user
    @duplicate_profile_set = duplicate_profile_set
  end

  def heading
    I18n.t('duplicate_profiles_detected.heading')
  end

  def associated_profiles
    profiles = Profile.where(id: duplicate_profile_set.profile_ids)
    profiles.map do |profile|
      dupe_user = profile.user
      sp_identity = ServiceProviderIdentity.find_by(
        user_id: dupe_user.id,
        service_provider: duplicate_profile_set.service_provider,
      )
      email = dupe_user.last_sign_in_email_address.email
      {
        email: email,
        masked_email: EmailMasker.mask(email),
        last_sign_in: sp_identity&.last_authenticated_at,
        created_at: dupe_user.created_at,
        connected_accts: user.connected_apps.count,
        current_account: dupe_user.id == user.id,
      }
    end
  end
end
