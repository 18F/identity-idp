module OtpSelectionValidator
  def valid_otp_delivery_selections?
    otp_params[:second_factor_ids].any?(&:present?)
  end

  private

  def otp_params
    params.require(:user).permit(:mobile, second_factor_ids: [])
  end
end
