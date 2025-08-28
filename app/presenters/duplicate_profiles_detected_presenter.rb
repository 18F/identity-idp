# frozen_string_literal: true

class DuplicateProfilesDetectedPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :user, :dupe_profile

  def initialize(user:, dupe_profile:)
    @user = user
    @dupe_profile = dupe_profile
  end

  def heading
    I18n.t('duplicate_profiles_detected.heading')
  end

  def associated_profiles
    profiles = Profile.where(id: dupe_profile.profile_ids)
    profiles.map do |profile|
      dupe_user = profile.user
      email = dupe_user.last_sign_in_email_address.email
      {
        email: email,
        masked_email: EmailMasker.mask(email),
        last_sign_in: dupe_user.last_sign_in_email_address.last_sign_in_at,
        created_at: dupe_user.created_at,
        connected_accts: user.connected_apps.count,
        current_account: dupe_user.id == user.id,
      }
    end
  end
end
