module Funnel
  module DocAuth
    class RegisterViewStep
      def self.call(doc_auth_log, token, _success)
        doc_auth_log.send("#{token}_view_at=".to_sym, Time.zone.now)
        value = doc_auth_log.send("#{token}_view_count".to_sym).to_i
        doc_auth_log.send("#{token}_view_count=".to_sym, value + 1)
        doc_auth_log.save
      end
    end
  end
end
