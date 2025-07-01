# frozen_string_literal: true

class DuplicateProfilesDetectedPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :user, :dupe_profile_confirmation

  def initialize(user:)
    @user = user
    @dupe_profile_confirmation = DuplicateProfileConfirmation.where(
      profile_id: user.active_profile.id,
    ).last
  end

  def heading
    I18n.t('duplicate_profiles_detected.heading')
  end

  def intro
    I18n.t('duplicate_profiles_detected.intro', app_name: APP_NAME)
  end

  def associated_profiles
    profile_ids = [user.active_profile] + dupe_profile_confirmation.duplicate_profile_ids 

    profiles = Profile.where(id: profile_ids)
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

  private

  def multiple_dupe_profiles?
    dupe_profile_confirmation.duplicate_profile_ids.count > 1
  end
end
