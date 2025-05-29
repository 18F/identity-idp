require 'rails_helper'

RSpec.describe Idv::InPerson::PassportController do
  include FlowPolicyHelper

  let(:user) { create(:user) }
  let(:document_capture_session) do
    create(:document_capture_session, user:, passport_status: 'requested')
  end
  let(:idv_session) { subject.idv_session }
  let(:enrollment) { create(:in_person_enrollment, :establishing, user: user) }

  before do
    stub_sign_in(user)
    stub_up_to(:hybrid_handoff, idv_session: subject.idv_session)
    allow(user).to receive(:establishing_in_person_enrollment).and_return(enrollment)
    subject.idv_session.document_capture_session_uuid = document_capture_session.uuid
    subject.user_session['idv/in_person'] = { pii_from_user: {} }
    stub_analytics
  end

  describe 'before_actions' do
    before do
      allow(idv_session).to receive(:in_person_passports_allowed?).and_return(true)
    end

    it 'includes before_action' do
      expect(subject).to have_actions(:before, :confirm_step_allowed)
      expect(subject).to have_actions(:before, :initialize_pii_from_user)
    end
  end

  describe '#show' do
    context 'when in person passports are not allowed' do
      before do
        allow(idv_session).to receive(:in_person_passports_allowed?).and_return(false)
      end

      it 'does not render the passport form' do
        expect(response).to_not render_template 'idv/in_person/passport/show'
      end

      it 'does not log the idv_in_person_proofing_passport_visited event' do
        expect(@analytics).to_not have_logged_event(:idv_in_person_proofing_passport_visited)
      end
    end

    context 'when in person passports are allowed' do
      before do
        allow(idv_session).to receive(:in_person_passports_allowed?).and_return(true)
      end

      let(:analytics_arguments) do
        {
          flow_path: 'standard',
          step: 'passport',
          analytics_id: 'In Person Proofing',
          skip_hybrid_handoff: false,
        }
      end

      before do
        subject.idv_session.opted_in_to_in_person_proofing =
          analytics_arguments[:opted_in_to_in_person_proofing]
        subject.idv_session.skip_hybrid_handoff = analytics_arguments[:skip_hybrid_handoff]
      end

      context 'when document_capture_session is "requested"' do
        before do
          subject.document_capture_session.update!(passport_status: 'requested')
        end

        context 'when there is no stored user pii' do
          before do
            subject.user_session['idv/in_person'] = { pii_from_user: {} }
            get :show
          end

          it 'renders the passport form' do
            expect(response).to render_template 'idv/in_person/passport/show'
            expect(enrollment.document_type).to eq(nil)
          end

          it 'logs the idv_in_person_proofing_passport_visited event' do
            expect(@analytics).to have_logged_event(
              :idv_in_person_proofing_passport_visited,
              analytics_arguments,
            )
          end
        end

        context 'when there is stored user pii' do
          let(:pii_from_user) do
            {
              'passport_surname' => Faker::Name.last_name,
              'passport_first_name' => Faker::Name.first_name,
              'passport_dob' => '1985-10-13',
              'passport_number' => '123456789',
              'passport_expiration' => '2100-12-12',
            }
          end

          before do
            subject.user_session['idv/in_person'] = { pii_from_user: }
            get :show
          end

          it 'renders the passport form' do
            expect(response).to render_template 'idv/in_person/passport/show'
            expect(enrollment.document_type).to eq(nil)
          end

          it 'logs the idv_in_person_proofing_passport_visited event' do
            expect(@analytics).to have_logged_event(
              :idv_in_person_proofing_passport_visited,
              analytics_arguments,
            )
          end
        end
      end

      context 'when document_capture_session is "not_requested"' do
        before do
          subject.document_capture_session.update!(passport_status: 'not_requested')
          get :show
        end

        it 'does not render the passport form' do
          expect(response).to_not render_template 'idv/in_person/passport/show'
        end

        it 'does not log the idv_in_person_proofing_passport_visited event' do
          expect(@analytics).to_not have_logged_event(:idv_in_person_proofing_passport_visited)
        end
      end
    end
  end

  describe '#update' do
    context 'when in person passports are allowed' do
      before do
        allow(idv_session).to receive(:in_person_passports_allowed?).and_return(true)
      end

      context 'when the form submit is successful' do
        let(:params) do
          {
            passport_surname: Faker::Name.last_name,
            passport_first_name: Faker::Name.first_name,
            passport_dob: {
              year: '1985',
              month: '10',
              day: '13',
            },
            passport_number: '123456789',
            passport_expiration: {
              year: '2100',
              month: '12',
              day: '25',
            },
          }
        end

        before do
          put :update, params: { in_person_passport: { **params } }
        end

        it 'logs the idv_in_person_proofing_passport_submitted event' do
          expect(@analytics).to have_logged_event(:idv_in_person_proofing_passport_submitted)
        end

        it 'stores the submitted data in the idv session' do
          expect(subject.idv_session.pii_from_user_in_session).to eq(
            {
              'passport_surname' => params[:passport_surname],
              'passport_first_name' => params[:passport_first_name],
              'passport_dob' => '1985-10-13',
              'passport_number' => params[:passport_number],
              'passport_expiration' => '2100-12-25',
            },
          )
        end

        it 'sets the enrollment document type' do
          expect(enrollment.document_type).to eq(InPersonEnrollment::DOCUMENT_TYPE_PASSPORT_BOOK)
        end

        it 'redirects to the address form' do
          expect(response).to redirect_to(idv_in_person_address_path)
        end
      end

      context 'when the form submit is unsuccessful' do
        let(:params) do
          {
            passport_surname: Faker::Name.last_name,
            passport_first_name: Faker::Name.first_name,
            passport_dob: {
              year: '1985',
              month: '10',
              day: '13',
            },
            passport_number: '12345',
            passport_expiration: {
              year: '2100',
              month: '12',
              day: '25',
            },
          }
        end

        before do
          put :update, params: { in_person_passport: { **params } }
        end

        it 'does not log the idv_in_person_proofing_passport_submitted event' do
          expect(@analytics).to_not have_logged_event(:idv_in_person_proofing_passport_submitted)
        end

        it 'does not store the submitted data in the idv session' do
          expect(subject.idv_session.pii_from_user_in_session).to eq({})
        end

        it 'does not set the enrollment document type' do
          expect(enrollment.document_type).to be_nil
        end

        it 'renders the passport form' do
          expect(response).to render_template :show
        end
      end
    end
  end

  describe '.step_info' do
    it 'returns a valid StepInfo Object' do
      expect(described_class.step_info).to be_valid
    end

    context 'undo_step' do
      let(:pii_from_user) do
        {
          'passport_surname' => Faker::Name.last_name,
          'passport_first_name' => Faker::Name.first_name,
          'passport_dob' => '1985-10-13',
          'passport_number' => '123456789',
          'passport_expiration' => '2100-12-12',
        }
      end

      before do
        subject.user_session['idv/in_person'] = { pii_from_user: }
        described_class.step_info.undo_step.call(idv_session: subject.idv_session, user:)
      end

      it 'removes user pii from the session' do
        expect(subject.idv_session.pii_from_user_in_session).to be_nil
      end
    end
  end
end
