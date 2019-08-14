module Idv
  module Flows
    class RecoveryFlow < Flow::BaseFlow
      STEPS = {
        recover: Idv::Steps::RecoverStep,
        overview: Idv::Steps::OverviewStep,
        upload: Idv::Steps::UploadStep,
        send_link: Idv::Steps::SendLinkStep,
        link_sent: Idv::Steps::LinkSentStep,
        email_sent: Idv::Steps::EmailSentStep,
        front_image: Idv::Steps::FrontImageStep,
        back_image: Idv::Steps::BackImageStep,
        mobile_front_image: Idv::Steps::MobileFrontImageStep,
        mobile_back_image: Idv::Steps::MobileBackImageStep,
        ssn: Idv::Steps::SsnStep,
        verify: Idv::Steps::VerifyStep,
        doc_success: Idv::Steps::RecoverDocSuccessStep,
        recover_fail: Idv::Steps::RecoverFailStep,
      }.freeze

      ACTIONS = {
        reset: Idv::Actions::ResetAction,
        redo_ssn: Idv::Actions::RedoSsnAction,
      }.freeze

      attr_reader :idv_session, :session # needed to support (and satisfy) the current LOA3 flow

      def initialize(controller, session, name)
        @session = session
        @idv_session = self.class.session_idv(session)
        super(controller, STEPS, ACTIONS, session[name])
      end

      def self.session_idv(session)
        session[:idv] ||= { params: {}, step_attempts: { phone: 0 } }
      end
    end
  end
end
