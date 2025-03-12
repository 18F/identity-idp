class AddTimestampsToRecaptchaAssessments < ActiveRecord::Migration[8.0]
  def change
    add_timestamps :recaptcha_assessments
    change_column_comment :recaptcha_assessments, :created_at, from: nil, to: 'sensitive=false'
    change_column_comment :recaptcha_assessments, :updated_at, from: nil, to: 'sensitive=false'
  end
end
