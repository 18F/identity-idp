module Db
  module ServiceProviderQuotaLimit
    class NotifyIfAnySpOverQuotaLimit
      def self.call
        return unless Db::ServiceProviderQuotaLimit::AnySpOverQuotaLimit.call
        email_list = IdentityConfig.store.sps_over_quota_limit_notify_email_list
        email_list.each do |email|
          ReportMailer.sps_over_quota_limit(email).deliver_now_or_later
        end
      end
    end
  end
end
