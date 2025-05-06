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

  def duplicate_profiles
    profile_ids = dupe_profile_confirmation.duplicate_profile_ids

    profiles = Profile.where(id: profile_ids)
    profiles.map do |profile|
      dupe_user = profile.user
      {
        email: dupe_user.last_sign_in_email_address.email,
        masked_email: masked_email(dupe_user.last_sign_in_email_address.email),
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
    dupe_profile_confirmation.duplicate_profile_ids.count > 1
  end

  def masked_email(email)
    email.gsub(/^(.+)@(.+)$/) do |_match|
      local_part = $1
      domain_part = "@#{$2}"
      local_length = local_part.length
      mask_char = '*'

      masked_local_part = case local_length
                          when 1 then mask_char
                          when 2 then mask_char * 2
                          else
                            hidden_length = local_length - 2
                            local_part[0] + (mask_char * hidden_length) + local_part[-1]
                          end
      masked_local_part + domain_part
    end
  end
end
