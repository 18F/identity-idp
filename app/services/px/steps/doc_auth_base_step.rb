module Px
  module Steps
    class DocAuthBaseStep < Idv::Steps::DocAuthBaseStep
      def throttled
        redirect_to px_verify_url
      end

      private

      def throttled_else_increment
        Throttler::IsThrottledElseIncrement.call(user_id, :px_acuant)
      end

      def idv_throttle_params
        [current_user.id, :px_resolution]
      end

      def idv_failure(result)
        attempter_increment
        if attempter_throttled?
          # TODO: Redirect to a special PX path
          redirect_to idv_session_errors_failure_url
        else
          # TODO: Redirect to a special PX path
          redirect_to idv_session_errors_warning_url
        end
        result
      end
    end
  end
end
