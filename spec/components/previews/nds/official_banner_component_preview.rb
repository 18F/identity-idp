module NDS
  # Net-new NDS official government banner. Add ?ui_test_bucket=nds to the
  # preview URL to load the NDS styles and see it.
  #
  # The banner opens its explainer through NDS::ModalComponent, which needs the
  # nds bucket to emit the .modal markup, so previews render inside the NDS
  # layout via ?ui_test_bucket=nds.
  class OfficialBannerComponentPreview < BaseComponentPreview
    def default
      render(NDS::OfficialBannerComponent.new)
    end
  end
end
