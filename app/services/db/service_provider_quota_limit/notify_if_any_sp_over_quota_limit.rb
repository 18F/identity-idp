module Db
  module ServiceProviderQuotaLimit
    class NotifyIfAnySpOverQuotaLimit
      def self.call
        email_list = JSON.parse(Figaro.env.sps_over_quota_limit_notify_email_list || '[]')
        email_list.each do |email|
          UserMailer.sps_over_quota_limit(email)
        end
      end
    end
  end
end
