module Idv
  module Flows
    class DocAuthFlow < Flow::BaseFlow
      STEPS = {
        welcome: Idv::Steps::WelcomeStep,
        agreement: Idv::Steps::AgreementStep,
        upload: Idv::Steps::UploadStep,
        send_link: Idv::Steps::SendLinkStep,
        link_sent: Idv::Steps::LinkSentStep,
        email_sent: Idv::Steps::EmailSentStep,
        document_capture: Idv::Steps::DocumentCaptureStep,
        ssn: Idv::Steps::SsnStep,
        verify: Idv::Steps::VerifyStep,
        verify_wait: Idv::Steps::VerifyWaitStep,
      }.freeze

      STEP_INDICATOR_STEPS = [
        { name: :getting_started },
        { name: :verify_id },
        { name: :verify_info },
        { name: :verify_phone_or_address },
        { name: :secure_account },
      ].freeze

      OPTIONAL_SHOW_STEPS = {
        verify_wait: Idv::Steps::VerifyWaitStepShow,
      }.freeze

      ACTIONS = {
        cancel_send_link: Idv::Actions::CancelSendLinkAction,
        cancel_link_sent: Idv::Actions::CancelLinkSentAction,
        cancel_update_ssn: Idv::Actions::CancelUpdateSsnAction,
        redo_address: Idv::Actions::RedoAddressAction,
        redo_ssn: Idv::Actions::RedoSsnAction,
        redo_document_capture: Idv::Actions::RedoDocumentCaptureAction,
        verify_document_status: Idv::Actions::VerifyDocumentStatusAction,
      }.freeze

      attr_reader :idv_session # this is needed to support (and satisfy) the current LOA3 flow

      def initialize(controller, session, name)
        @idv_session = self.class.session_idv(session)
        super(controller, STEPS, ACTIONS, session[name])
      end

      def self.session_idv(session)
        session[:idv] ||= {}
      end
    end
  end
end
