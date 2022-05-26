module Idv
  module Steps
    module Ipp
      class BarcodeStep < DocAuthBaseStep
        # i18n-tasks-use t('step_indicator.flows.idv.go_to_the_post_office')
        STEP_INDICATOR_STEP = :go_to_the_post_office
        def call; end
      end
    end
  end
end
