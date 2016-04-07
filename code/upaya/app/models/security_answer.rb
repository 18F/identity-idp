class SecurityAnswer < ActiveRecord::Base
  attr_encrypted :text,
                 algorithm: 'aes-256-cbc',
                 key: Figaro.env.security_answer_encryption_key,
                 mode: :per_attribute_iv_and_salt

  belongs_to :user
  belongs_to :security_question

  validates :text, presence: true
  validates :security_question_id,
            presence: true,
            uniqueness: { scope: :user_id }
  validates :user, presence: true

  def normalized_text
    text.downcase
  end

  def question
    return if security_question_id.blank?
    SecurityQuestion.find(security_question_id).question
  end

  def match?(other)
    id == other.id && normalized_text == other.normalized_text
  end

  # params - A Hash of the format {text: 'ANSWER', id: 'ANSWER_ID'}
  def match_params?(params)
    params = params.with_indifferent_access
    other = self.class.new(text: params[:text], id: params[:id])
    match?(other)
  end
end
