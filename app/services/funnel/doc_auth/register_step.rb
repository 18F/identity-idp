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
        personal_key
      ].freeze

      def self.call(user_id, token, step_type, success)
        return unless user_id
        doc_auth_log = DocAuthLog.find_or_create_by(user_id: user_id)
        return unless TOKEN_WHITELIST.index(token.to_sym)
        klass = step_type == :update ?  RegisterSubmitStep : RegisterViewStep
        klass.call(doc_auth_log, token, success)
      end
    end
  end
end
