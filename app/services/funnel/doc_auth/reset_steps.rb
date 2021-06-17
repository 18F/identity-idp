module Funnel
  module DocAuth
    class ResetSteps
      SKIP_FIELDS = %w[id user_id created_at updated_at].freeze

      def self.call(user_id)
        doc_auth_log = DocAuthLog.find_by(user_id: user_id)
        return unless doc_auth_log
        DocAuthLog.new.attributes.keys.each do |attribute|
          next if SKIP_FIELDS.index(attribute)
          reset_attributes(doc_auth_log, attribute)
        end
        doc_auth_log.save
      end

      def self.reset_attributes(doc_auth_log, attribute)
        doc_auth_log[attribute] = nil if /at$/.match?(attribute)
        doc_auth_log[attribute] = 0 if /count$/.match?(attribute)
      end
      private_class_method :reset_attributes
    end
  end
end
