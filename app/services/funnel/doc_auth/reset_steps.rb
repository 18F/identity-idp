module Funnel
  module DocAuth
    class ResetSteps
      def self.call(user_id)
        doc_auth_log = DocAuthLog.find_or_create_by(user_id: user_id)
        DocAuthLog.new.attributes.keys.each do |method|
          case method
          when /at$/
            doc_auth_log.send("#{method}=".to_sym, nil)
          when /count$/
            doc_auth_log.send("#{method}=".to_sym, 0)
          end
        end
        doc_auth_log.save
      end
    end
  end
end
