module FormHelper
  def app_setting_value_field_for(app_setting, f)
    if app_setting.boolean?
      f.input :value, collection: [%w(Enabled 1), %w(Disabled 0)], include_blank: false
    else
      f.input :value
    end
  end

  def security_questions_collection_for(answer)
    return active_questions if answer.id.nil?

    if !SecurityQuestion.find(answer.security_question_id).active?
      active_questions.push([answer.question, answer.security_question_id])
    else
      active_questions
    end
  end

  def active_questions
    SecurityQuestion.where(active: true).pluck(:question, :id)
  end

  def list_answers(answer_array)
    # 6b17798... initial checkin for IDPaaS ui
  end
end
