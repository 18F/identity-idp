# frozen_string_literal: true

class DuplicateProfilesDetectedPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :user, :user_session

  def initialize(user:, user_session:)
    @user = user
    @user_session = user_session
  end

  def heading
    I18n.t('duplicate_profiles_detected.heading')
  end

  def intro
    I18n.t('duplicate_profiles_detected.intro', app_name: APP_NAME)
  end

  def duplicate_profiles
    profile_ids = user_session[:duplicate_profile_ids]

    profiles = Profile.where(id: profile_ids)
    profiles.map do |profile|
      dupe_user = profile.user
      email = dupe_user.last_sign_in_email_address.email
      {
        email: email,
        masked_email: EmailMasker.mask(email),
        last_sign_in: dupe_user.last_sign_in_email_address.last_sign_in_at,
        created_at: dupe_user.created_at,
      }
    end
  end

  def recognize_all_profiles
    if multiple_dupe_profiles?
      I18n.t('duplicate_profiles_detected.yes_many')
    else
      I18n.t('duplicate_profiles_detected.yes_single')
    end
  end

  def dont_recognize_some_profiles
    if multiple_dupe_profiles?
      I18n.t('duplicate_profiles_detected.no_recognize_many')
    else
      I18n.t('duplicate_profiles_detected.no_recognize_single')
    end
  end

  private

  def multiple_dupe_profiles?
    user_session[:duplicate_profile_ids].count > 1
  end
end
