require "#{Rails.root}/lib/security_question_populator"
include SecurityQuestionPopulator

# create second factors (email and sms)
%w(Email Mobile).map { |factor| SecondFactor.find_or_create_by!(name: factor) }

AppSetting.find_or_create_by!(name: 'RegistrationsEnabled') do |setting|
  setting.value = '1'
end

populate_security_questions unless Rails.env.test?
