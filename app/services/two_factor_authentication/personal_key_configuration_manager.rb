module TwoFactorAuthentication
  class PersonalKeyConfigurationManager < TwoFactorAuthentication::ConfigurationManager
    def enabled?
      personal_key.present?
    end

    def configured?
      personal_key.present?
    end

    def configurable?
      false # we can always create a new personal key, but not as part of the 2fa process
    end

    ###
    ### Method-specific data management
    ###

    delegate :active_profile, :personal_key, to: :user

    # :reek:FeatureEnvy
    def should_acknowledge?(session)
      return true if session[:personal_key]

      sp_session = session[:sp]

      !configured? && (sp_session.blank? || sp_session[:loa3] == false)
    end

    def create_new_code(session)
      if active_profile.present?
        Pii::ReEncryptor.new(user: user, user_session: session).perform
        active_profile.personal_key
      else
        PersonalKeyGenerator.new(user).create
      end
    end
  end
end
