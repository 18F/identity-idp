module Funnel
  module DocAuth
    class RegisterCampaign
      def self.call(user_id, campaign)
        return unless campaign_whitelisted?(campaign)
        doc_auth_log = DocAuthLog.find_by(user_id: user_id)
        return if doc_auth_log.nil? || doc_auth_log.no_sp_campaign
        doc_auth_log.no_sp_campaign = campaign.to_s
        doc_auth_log.no_sp_session_started_at = Time.zone.now
        doc_auth_log.save
      end

      def self.campaign_whitelisted?(campaign)
        whitelist = JSON.parse(Identity::Hostdata.settings.no_sp_campaigns_whitelist || '[]')
        whitelist.include?(campaign)
      end
      private_class_method :campaign_whitelisted?
    end
  end
end
