class SetupPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :current_user, :user_fully_authenticated, :user_opted_remember_device_cookie

  def initialize(current_user:, user_fully_authenticated:, user_opted_remember_device_cookie:,
                 remember_device_default:)
    @current_user = current_user
    @user_fully_authenticated = user_fully_authenticated
    @user_opted_remember_device_cookie = user_opted_remember_device_cookie
    @remember_device_default = remember_device_default
  end

  def remember_device_box_checked?
    return @remember_device_default if user_opted_remember_device_cookie.nil?
    ActiveModel::Type::Boolean.new.cast(user_opted_remember_device_cookie)
  end

  def outage_message
    if VendorStatus.new.vendor_outage?(:voice)
      t('vendor_outage.voice.alert')
    elsif VendorStatus.new.vendor_outage?(:sms)
      t('vendor_outage.sms.alert')
    end
  end
end
