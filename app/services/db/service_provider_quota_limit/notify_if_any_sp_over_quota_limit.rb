module Db
  module ServiceProviderQuotaLimit
    class NotifyIfAnySpOverQuotaLimit
      def self.call
        return unless Db::ServiceProviderQuotaLimit::AnySpOverQuotaLimit.call
        email_list = JSON.parse(AppConfig.env.sps_over_quota_limit_notify_email_list || '[]')
        email_list.each do |email|
          UserMailer.sps_over_quota_limit(email).deliver_now
        end
      end
    end
  end
end
