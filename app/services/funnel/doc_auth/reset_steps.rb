module Funnel
  module DocAuth
    class ResetSteps
      def self.call(user_id)
        doc_auth_log = DocAuthLog.find_or_create_by(user_id: user_id)
        DocAuthLog.new.attributes.keys.each do |method|
          assignment = "#{method}=".to_sym
          doc_auth_log.send(assignment, nil) if method =~ /at$/
          doc_auth_log.send(assignment, 0) if method =~ /count$/
        end
        doc_auth_log.save
      end
    end
  end
end
