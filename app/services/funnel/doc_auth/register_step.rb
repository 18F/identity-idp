module Funnel
  module DocAuth
    class RegisterStep
      TOKEN_WHITELIST = %i[
        welcome
        upload
        send_link
        link_sent
        email_sent
        front_image
        back_image
        mobile_front_image
        mobile_back_image
        ssn
        verify
        verify_phone
        encrypt
        verified
        doc_success
        usps_address
        usps_letter_sent
        capture_mobile_back_image
        capture_complete
      ].freeze
      STEP_TYPE_TO_CLASS = {
        update: RegisterSubmitStep,
        view: RegisterViewStep,
      }.freeze

      def self.call(user_id, token, step_type, success)
        return unless user_id && TOKEN_WHITELIST.index(token.to_sym)
        doc_auth_log = find_or_create_doc_auth_log(user_id, token)
        return unless doc_auth_log
        klass = STEP_TYPE_TO_CLASS[step_type]
        klass.call(doc_auth_log, token, success)
      end

      # :reek:ControlParameter
      def self.find_or_create_doc_auth_log(user_id, token)
        doc_auth_log = DocAuthLog.find_by(user_id: user_id)
        return doc_auth_log if doc_auth_log
        return unless token == 'welcome'
        DocAuthLog.create(user_id: user_id)
      end
      private_class_method :find_or_create_doc_auth_log
    end
  end
end
