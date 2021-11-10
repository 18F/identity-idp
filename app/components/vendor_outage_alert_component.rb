class VendorOutageAlertComponent < BaseComponent
  include LinkHelper

  attr_reader :vendors, :context

  def initialize(vendors:, context: 'default')
    @vendors = vendors
    @context = context
  end

  def content
    case outages.sort
    when [:sms, :voice]
      t(context, scope: 'vendor_outage.alerts.phone', default: :default)
    when [:sms]
      t(context, scope: 'vendor_outage.alerts.sms', default: :default)
    when [:voice]
      t(context, scope: 'vendor_outage.alerts.voice', default: :default)
    end
  end

  private

  def outages
    vendor_status = VendorStatus.new
    vendors.select { |vendor| vendor_status.vendor_outage?(vendor) }
  end
end
