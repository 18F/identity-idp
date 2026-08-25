# frozen_string_literal: true

module NDS
  # Net-new NDS official government banner. Renders only in the NDS layout via
  # NDS::PageChromeComponent. Emits .official-banner markup with a "how you
  # know" button that opens an explainer dialog rendered through
  # NDS::ModalComponent (.modal).
  class OfficialBannerComponent < BaseComponent
    DIALOG_ID = 'official-banner-modal'

    def dialog_id
      DIALOG_ID
    end

    def show_test_notice?
      FeatureManagement.show_no_pii_banner?
    end
  end
end
