module Idv
  module Flows
    class DocAuthFlow < Flow::BaseFlow
      STEPS = {
        welcome: Idv::Steps::WelcomeStep,
        upload: Idv::Steps::UploadStep,
        send_link: Idv::Steps::SendLinkStep,
        link_sent: Idv::Steps::LinkSentStep,
        email_sent: Idv::Steps::EmailSentStep,
        front_image: Idv::Steps::FrontImageStep,
        back_image: Idv::Steps::BackImageStep,
        mobile_front_image: Idv::Steps::MobileFrontImageStep,
        mobile_back_image: Idv::Steps::MobileBackImageStep,
        ssn: Idv::Steps::SsnStep,
        doc_failed: Idv::Steps::DocFailedStep,
        doc_success: Idv::Steps::DocSuccessStep,
      }.freeze

      ACTIONS = {
        reset: Idv::Actions::ResetAction,
      }.freeze

      PRESENTERS = {
        front_image: Idv::Presenters::DocAuthPresenter,
      }.freeze

      attr_reader :idv_session # this is needed to support (and satisfy) the current LOA3 flow

      def initialize(session, current_user, name)
        @idv_session = self.class.session_idv(session)
        super(STEPS, ACTIONS, session[name], current_user)
      end

      def self.session_idv(session)
        session[:idv] ||= { params: {}, step_attempts: { phone: 0 } }
      end
    end
  end
end
