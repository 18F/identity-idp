module Funnel
  module DocAuth
    class RegisterStep
      TOKEN_ALLOWLIST = %i[
        agreement
        welcome
        upload
        link_sent
        front_image
        back_image
        mobile_front_image
        mobile_back_image
        ssn
        verify
        verify_phone
        encrypt
        verified
        usps_address
        usps_letter_sent
        capture_mobile_back_image
        capture_complete
        choose_method
        present_cac
        enter_info
        success
        document_capture
      ].freeze
      STEP_TYPE_TO_CLASS = {
        update: RegisterSubmitStep,
        view: RegisterViewStep,
      }.freeze

      def initialize(user_id, issuer)
        @user_id = user_id
        @issuer = issuer
      end

      def call(token, step_type, success)
        return unless user_id && TOKEN_ALLOWLIST.index(token.to_sym)
        doc_auth_log = find_or_create_doc_auth_log(user_id, token)
        return unless doc_auth_log
        klass = STEP_TYPE_TO_CLASS[step_type]
        klass.call(doc_auth_log, issuer, token, success)
      end

      private

      attr_reader :user_id, :issuer

      def find_or_create_doc_auth_log(user_id, token)
        doc_auth_log = DocAuthLog.find_by(user_id:)
        return doc_auth_log if doc_auth_log
        return unless token == 'welcome'
        DocAuthLog.create(user_id:)
      end
    end
  end
end
