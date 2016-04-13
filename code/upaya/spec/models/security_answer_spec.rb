describe SecurityAnswer do
  let(:user) { create(:user) }
  let(:security_answer) { create(:security_answer, user_id: user.id, security_question_id: SecurityQuestion.pluck(:id).first) }
  subject { security_answer }

  it { is_expected.to belong_to(:security_question) }
  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:text) }
  it { is_expected.to validate_presence_of(:security_question_id) }
  it { is_expected.to validate_presence_of(:user) }
  it { is_expected.to validate_uniqueness_of(:security_question_id).scoped_to(:user_id) }

  describe '#question' do
    it "returns the answer's security question" do
      expect(security_answer.question).
        to eq SecurityQuestion.find(security_answer.security_question_id).question
    end
  end
end
