module Funnel
  module DocAuth
    class RegisterSubmitStep
      def self.call(doc_auth_log, token, success)
        method = "#{token}_submit_count".to_sym
        value = doc_auth_log.send(method).to_i
        doc_auth_log.send("#{method}=".to_sym, value + 1)
        method = "#{token}_error_count".to_sym
        unless success
          value = doc_auth_log.send(method).to_i
          doc_auth_log.send("#{method}=".to_sym, value + 1)
        end
        doc_auth_log.save
      end
    end
  end
end
