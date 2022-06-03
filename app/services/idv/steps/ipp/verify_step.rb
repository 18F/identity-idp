module Idv
  module Steps
    module Ipp
      class VerifyStep < DocAuthBaseStep
        STEP_INDICATOR_STEP = :verify_info
        def call
          # send the user to the phone page where they'll continue the remainder of
          # the idv flow
          redirect_to idv_phone_url
        end
      end
    end
  end
end
