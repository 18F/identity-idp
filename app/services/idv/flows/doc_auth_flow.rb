module Idv
  module Flows
    class DocAuthFlow < Flow::BaseFlow
      STEPS = {
        welcome: Idv::Steps::WelcomeStep,
        upload: Idv::Steps::UploadStep,
        send_link: Idv::Steps::SendLinkStep,
        link_sent: Idv::Steps::LinkSentStep,
        email_sent: Idv::Steps::EmailSentStep,
        document_capture: Idv::Steps::DocumentCaptureStep,
        front_image: Idv::Steps::FrontImageStep,
        back_image: Idv::Steps::BackImageStep,
        mobile_front_image: Idv::Steps::MobileFrontImageStep,
        mobile_back_image: Idv::Steps::MobileBackImageStep,
        selfie: Idv::Steps::SelfieStep,
        ssn: Idv::Steps::SsnStep,
        verify: Idv::Steps::VerifyStep,
        verify_wait: Idv::Steps::VerifyWaitStep,
        doc_success: Idv::Steps::DocSuccessStep,
      }.freeze
      OPTIONAL_SHOW_STEPS = {
        verify_wait: Idv::Steps::VerifyWaitStepShow,
      }

      ACTIONS = {
        reset: Idv::Actions::ResetAction,
        redo_ssn: Idv::Actions::RedoSsnAction,
      }.freeze

      attr_reader :idv_session # this is needed to support (and satisfy) the current LOA3 flow

      def initialize(controller, session, name)
        @idv_session = self.class.session_idv(session)
        super(controller, STEPS, ACTIONS, session[name])
      end

      def self.session_idv(session)
        session[:idv] ||= { params: {}, step_attempts: { phone: 0 } }
      end
    end
  end
end
