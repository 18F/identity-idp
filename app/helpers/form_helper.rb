module FormHelper
  def app_setting_value_field_for(app_setting, f)
    if app_setting.boolean?
      f.input :value, collection: [%w(Enabled 1), %w(Disabled 0)], include_blank: false
    else
      f.input :value
    end
  end
end
