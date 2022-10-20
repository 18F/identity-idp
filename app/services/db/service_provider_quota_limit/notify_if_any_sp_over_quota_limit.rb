module Db
  module ServiceProviderQuotaLimit
    class NotifyIfAnySpOverQuotaLimit
      def self.call
        return unless Db::ServiceProviderQuotaLimit::AnySpOverQuotaLimit.call
        email_list = IdentityConfig.store.sps_over_quota_limit_notify_email_list
        email_list.each do |email|
          # rubocop:disable IdentityIdp/MailLaterLinter
          ReportMailer.sps_over_quota_limit(email).deliver_now
          # rubocop:enable IdentityIdp/MailLaterLinter
        end
      end
    end
  end
end
