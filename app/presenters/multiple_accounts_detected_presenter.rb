# frozen_string_literal: true

class MultipleAccountsDetectedPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :user, :duplicate_profile_confirmation

  def initialize(user:)
      @user = user
      @duplicate_profile_confirmation = DuplicateProfileConfirmation.where(profile_id: user.active_profile.id).last
  end


  def heading
    I18n.t('multiple_accounts_detected.heading')
  end

  def intro
    I18n.t('multiple_accounts_detected.intro', app_name: APP_NAME)
  end

  def other_accounts_detected
    profile_ids = duplicate_profile_confirmation.duplicate_profile_ids

    profiles = Profile.where(id: profile_ids)
    profiles.map do |profile|
      dupe_user = profile.user
      {
        email: obfuscated_email(dupe_user.last_sign_in_email_address.email),
        last_sign_in: dupe_user.last_sign_in_email_address.last_sign_in_at,
     }
    end
  end

  private 
  
  def obfuscated_email(email)
    email
  end
end
  