module Funnel
  module DocAuth
    class RegisterSubmitStep
      def self.call(doc_auth_log, token, success)
        method = "#{token}_submit_count".to_sym
        if doc_auth_log.respond_to?(method)
          value = doc_auth_log.send(method).to_i
          doc_auth_log.send("#{method}=".to_sym, value + 1)
          doc_auth_log.save
        end
        method = "#{token}_error_count".to_sym
        if doc_auth_log.respond_to?(method) && !success
          value = doc_auth_log.send(method).to_i
          doc_auth_log.send("#{method}=".to_sym, value + 1)
          doc_auth_log.save
        end
      end
    end
  end
end
