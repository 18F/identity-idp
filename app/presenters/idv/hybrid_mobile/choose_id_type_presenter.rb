# frozen_string_literal: true

class Idv::HybridMobile::ChooseIdTypePresenter < Idv::ChooseIdTypePresenter
  include ActionView::Helpers::TranslationHelper

  def hybrid_flow?
    true
  end
end
