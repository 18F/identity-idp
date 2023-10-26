module Idv
  class HowToVerifyController < ApplicationController
  def show
    @idv_how_to_verify_form = Idv::HowToVerifyForm.new
  end

  def update
    if how_to_verify_form_params['selection'] == 'ipp'
      redirect_to idv_document_capture_url
    else
      redirect_to idv_hybrid_handoff_url
    end
  end

  private

  def how_to_verify_form_params
    params.require(:idv_how_to_verify_form).permit(:selection)
  end
end
