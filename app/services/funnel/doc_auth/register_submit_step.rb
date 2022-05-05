module Funnel
  module DocAuth
    class RegisterSubmitStep
      def self.call(doc_auth_log, issuer, token, success)
        update_submit_count(doc_auth_log, issuer, token)
        update_error_count(doc_auth_log, token, success)
      end

      def self.update_submit_count(doc_auth_log, issuer, token)
        method = "#{token}_submit_count".to_sym
        return unless doc_auth_log.respond_to?(method)
        doc_auth_log[method] += 1
        method = "#{token}_submit_at".to_sym
        doc_auth_log[method] = Time.zone.now if doc_auth_log.respond_to?(method)
        doc_auth_log.issuer = issuer
        doc_auth_log.save
      end
      private_class_method :update_submit_count

      def self.update_error_count(doc_auth_log, token, success)
        error_count = "#{token}_error_count".to_sym
        return unless doc_auth_log.respond_to?(error_count) && !success
        doc_auth_log[error_count] += 1
        doc_auth_log.save
      end
      private_class_method :update_error_count
    end
  end
end
