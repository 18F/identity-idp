class SessionsNew
  def title
    I18n.t('idv.titles.session.basic')
  end

  def mock_vendor_partial
    if idv_vendor.pick == :mock
      'verify/sessions/no_pii_warning'
    else
      'shared/null'
    end
  end

  private

  def idv_vendor
    @_idv_vendor ||= Idv::Vendor.new
  end
end
