module Funnel
  module DocAuth
    class RegisterCampaign
      def self.call(user_id, campaign)
        doc_auth_log = DocAuthLog.find_by(user_id: user_id)
        return if doc_auth_log.nil? || doc_auth_log.no_sp_campaign
        doc_auth_log.no_sp_campaign = campaign.to_s
        doc_auth_log.no_sp_at = Time.zone.now
        doc_auth_log.save
      end
    end
  end
end
