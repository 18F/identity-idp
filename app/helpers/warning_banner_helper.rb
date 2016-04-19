require 'feature_management'

module WarningBannerHelper
  def warning_banner_text
    any_otp_content if FeatureManagement.pt_mode?
  end

  def any_otp_content
    concat(content_tag(:strong) do
      'Performance Testing Mode!'
    end)
    'OTPs are not secure. Any old OTP is allowed!'
  end
end
