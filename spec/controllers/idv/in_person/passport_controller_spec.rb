require 'rails_helper'

RSpec.describe Idv::InPerson::PassportController do
  include Idv::AvailabilityConcern
  include IdvStepConcern

  # let(:user) { build(:user) }
  # let(:enrollment) { InPersonEnrollment.new }

  before do
    # stub_sign_in(user)
    # stub_up_to(:hybrid_handoff, idv_session: subject.idv_session)
    # allow(user).to receive(:establishing_in_person_enrollment).and_return(enrollment)
    # subject.user_session['idv/in_person'] = { pii_from_user: {} }
    # subject.idv_session.ssn = nil
    # stub_analytics
  end

  describe 'before_action' do
    it 'includes correct before_actions' do

    end
  end
end