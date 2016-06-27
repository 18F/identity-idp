require 'rails_helper'

require 'proofer/vendor/mock'

describe Idv::ConfirmationsController do
  render_views

  let(:user) { create(:user, :signed_up, email: 'old_email@example.com') }
  let(:applicant) { Proofer::Applicant.new first_name: 'Some', last_name: 'One' }
  let(:agent) { Proofer::Agent.new vendor: :mock }
  let(:resolution) { agent.start applicant }
  let(:pii) { PII.create_from_proofer_applicant(applicant, user) }

  describe 'before_actions' do
    it 'includes before_actions from AccountStateChecker' do
      expect(subject).to have_filters(
        :before,
        :confirm_two_factor_authenticated
      )
    end
  end

  describe '#index' do
    before(:each) do
      init_idv_session
    end

    it 'verifies and activates PII on successful confirmation' do
      get :index

      expect(response.body).to include(t('idv.titles.complete'))
      pii.reload
      expect(pii).to be_active
      expect(pii).to be_verified
    end
  end

  def init_idv_session
    sign_in(user)
    answer_all_questions
    subject.user_session[:idv] = {
      vendor: :mock,
      applicant: applicant,
      pii_id: pii.id,
      resolution: resolution,
      question_number: resolution.questions.count + 1
    }
  end

  def answer_all_questions
    Proofer::Vendor::Mock::ANSWERS.each do |ques, answ|
      resolution.questions.find_by_key(ques).answer = answ
    end
  end
end
