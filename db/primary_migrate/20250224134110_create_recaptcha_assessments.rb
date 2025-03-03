class CreateRecaptchaAssessments < ActiveRecord::Migration[8.0]
  def change
    create_table :recaptcha_assessments, id: :string do |t|
      t.string :annotation, comment: 'sensitive=false'
      t.string :annotation_reason, comment: 'sensitive=false'
    end
  end
end
