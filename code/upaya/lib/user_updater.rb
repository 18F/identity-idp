module UserUpdater
  def self.confirm_2fa_for(user)
    user.update!(second_factor_ids: [SecondFactor.find_by_name('Email').id])
    user.update!(second_factor_confirmed_at: Time.zone.now)
  end

  def self.create_security_answers_for(user)
    SecurityQuestion.where(active: true).limit(5).pluck(:id).each do |id|
      user.security_answers.create!(text: 'My answer', security_question_id: id)
    end
  end
end
