# frozen_string_literal: true

class Idv::HybridMobile::ChooseIdTypePresenter < Idv::ChooseIdTypePresenter

  def initialize(mdl_enabled: false)
    super(mdl_enabled:)
  end

  def hybrid_flow?
    true
  end
end
