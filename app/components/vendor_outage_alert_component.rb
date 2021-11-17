class VendorOutageAlertComponent < BaseComponent
  include LinkHelper

  def initialize(vendors:, only_if_all: false, context: 'default')
    @vendors = vendors
    @only_if_all = only_if_all
    @context = context
  end

  def content
    case outages.sort
    when [:sms, :voice]
      # i18n-tasks-use t('vendor_outage.alerts.phone.default')
      # i18n-tasks-use t('vendor_outage.alerts.phone.idv')
      t(context, scope: 'vendor_outage.alerts.phone', default: :default)
    when [:sms]
      # i18n-tasks-use t('vendor_outage.alerts.sms.default')
      # i18n-tasks-use t('vendor_outage.alerts.sms.idv')
      t(context, scope: 'vendor_outage.alerts.sms', default: :default)
    when [:voice]
      # i18n-tasks-use t('vendor_outage.alerts.voice.default')
      # i18n-tasks-use t('vendor_outage.alerts.voice.idv')
      t(context, scope: 'vendor_outage.alerts.voice', default: :default)
    end
  end

  private

  attr_reader :vendors, :only_if_all, :context

  def outages
    if only_if_all
      vendor_status.all_vendor_outage?(vendors) ? vendors : []
    else
      vendors.select { |vendor| vendor_status.vendor_outage?(vendor) }
    end
  end

  def vendor_status
    @vendor_status ||= VendorStatus.new
  end
end
