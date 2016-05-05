class RemoveSecurityQuestionFieldsFromUsers < ActiveRecord::Migration
  def change
    remove_column :users, :security_question_attempts_count
    remove_column :users, :security_questions_answered_at
  end
end
