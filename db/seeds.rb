# create second factors (email and sms)
%w(Email Mobile).map { |factor| SecondFactor.find_or_create_by!(name: factor) }

# enable registrations by default
AppSetting.find_or_create_by!(name: 'RegistrationsEnabled') do |setting|
  setting.value = '1'
end
