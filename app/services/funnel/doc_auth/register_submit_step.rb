module Funnel
  module DocAuth
    class RegisterSubmitStep
      def self.call(doc_auth_log, token, success)
        method = "#{token}_submit_count".to_sym
        if doc_auth_log.respond_to?(method)
          doc_auth_log.send("#{method}=".to_sym, doc_auth_log.send(method).to_i + 1)
          doc_auth_log.save
        end
        error_count = "#{token}_error_count".to_sym
        if doc_auth_log.respond_to?(error_count) && !success
          doc_auth_log.send("#{error_count}=".to_sym, doc_auth_log.send(error_count).to_i + 1)
          doc_auth_log.save
        end
      end
    end
  end
end
