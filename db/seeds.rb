# enable registrations by default
AppSetting.find_or_create_by!(name: 'RegistrationsEnabled') do |setting|
  setting.value = '1'
end

if Rails.env.development?
  # Create a few dummy accounts for use during development.  These accounts all
  # have 'password' as password and are setup for mobile OTP delivery.
  mobile = 4_155_555_555
  %w(test1@test.com test2@test.com).each do |email|
    User.find_or_create_by!(email: email) do |user|
      user.skip_confirmation!
      user.reset_password('password', 'password')
      user.unconfirmed_mobile = mobile.to_s
      user.mobile_confirm
    end
    mobile += 1
  end
end
