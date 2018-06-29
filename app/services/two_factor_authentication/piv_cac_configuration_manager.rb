module TwoFactorAuthentication
  class PivCacConfigurationManager < ConfigurationManager
    def enabled?
      x509_dn_uuid.present?
    end

    def available?
      enabled? || user.identities.any?(&:piv_cac_available?)
    end

    def configured?
      enabled?
    end

    ###
    ### Method-specific data management
    ###
    delegate :x509_dn_uuid=, :x509_dn_uuid, to: :user

    def save_configuration
      user.save!
      Event.create(user_id: user.id, event_type: :piv_cac_enabled)
    end

    def remove_configuration
      return unless configured?
      user.update!(x509_dn_uuid: nil)
      Event.create(user_id: user.id, event_type: :piv_cac_disabled)
    end

    def authenticate(proposed_uuid)
      x509_dn_uuid.present? && proposed_uuid.present? && proposed_uuid == x509_dn_uuid
    end

    # the real question is if someone else has this configuration already.
    # Note that this will return true if the user is configured and we're searching for the
    # user's x509_dn_uuid. But this doesn't hinder configuration since we won't try to
    # configure a piv/cac for someone who already has one.
    def associated?
      User.find_by(x509_dn_uuid: x509_dn_uuid).present?
    end
  end
end
