module Funnel
  module DocAuth
    class ResetSteps
      def self.call(user_id)
        doc_auth_log = DocAuthLog.find_or_create_by(user_id: user_id)
        DocAuthLog.new.attributes.keys.each do |attribute|
          doc_auth_log[attribute] = nil if attribute =~ /at$/
          doc_auth_log[attribute] = 0 if attribute =~ /count$/
        end
        doc_auth_log.save
      end
    end
  end
end
