class DropSecurityQuestions < ActiveRecord::Migration
  def change
    drop_table :security_questions
  end
end
