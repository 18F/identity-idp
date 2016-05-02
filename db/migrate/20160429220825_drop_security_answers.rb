class DropSecurityAnswers < ActiveRecord::Migration
  def change
    drop_table :security_answers
  end
end
