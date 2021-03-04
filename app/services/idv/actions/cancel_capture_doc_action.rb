module Idv
  module Actions
    class CancelCaptureDocAction < Idv::Steps::DocAuthBaseStep
      def call
        dcs = document_capture_session
        return unless dcs
        dcs.cancelled_at = Time.zone.now
        dcs.save!
        redirect_to idv_cancel_url
      end
    end
  end
end
