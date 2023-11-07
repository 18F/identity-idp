require 'rails_helper'

RSpec.describe Idv::Steps::InPerson::AddressStep do
  include InPersonHelper
  let(:submitted_values) { {} }
  let(:pii_from_user) { flow.flow_session[:pii_from_user] }
  let(:params) { ActionController::Parameters.new({ in_person_address: submitted_values }) }
  let(:enrollment) { InPersonEnrollment.new }
  let(:user) { build(:user) }
  let(:service_provider) { create(:service_provider) }
  let(:controller) do
    instance_double(
      'controller',
      session: { sp: { issuer: service_provider.issuer } },
      params:,
      current_user: user,
      url_options: {},
    )
  end

  let(:flow) do
    Idv::Flows::InPersonFlow.new(controller, {}, 'idv/in_person')
  end

  subject(:step) do
    Idv::Steps::InPerson::AddressStep.new(flow)
  end

  before(:each) do
    allow(step).to receive(:current_user).
      and_return(user)
    allow(user).to receive(:establishing_in_person_enrollment).
      and_return(enrollment)
  end

  describe '#call' do
    context 'with values submitted' do
      let(:address1) { '1 FAKE RD' }
      let(:address2) { 'APT 1B' }
      let(:city) { 'GREAT FALLS' }
      let(:zipcode) { '59010' }
      let(:state) { 'Montana' }
      let(:same_address_as_id) { 'false' }
      let(:submitted_values) do
        {
          address1:,
          address2:,
          city:,
          zipcode:,
          state:,
          same_address_as_id:,
        }
      end

      before(:each) do
        Idv::InPerson::AddressForm::ATTRIBUTES.each do |attr|
          expect(flow.flow_session[:pii_from_user]).to_not have_key attr
        end
      end

      it 'sets the values in flow session' do
        step.call

        expect(flow.flow_session[:pii_from_user]).to include(
          address1:,
          address2:,
          city:,
          zipcode:,
          state:,
        )
      end

      context 'when initially entering the residential address' do
        it 'leaves the "same_address_as_id" attr as false' do
          flow.flow_session[:pii_from_user][:same_address_as_id] = 'false'
          step.call

          expect(flow.flow_session[:pii_from_user][:same_address_as_id]).to eq('false')
        end
      end

      context 'when updating the residential address' do
        before(:each) do
          flow.flow_session[:pii_from_user][:address1] = '123 New Residential Ave'
        end

        context 'user previously selected that the residential address matched state ID' do
          before(:each) do
            flow.flow_session[:pii_from_user][:same_address_as_id] = 'true'
          end

          it 'infers and sets the "same_address_as_id" in the flow session to false' do
            step.call
            expect(flow.flow_session[:pii_from_user][:same_address_as_id]).to eq('false')
          end
        end

        context 'user previously selected that the residential address did not match state ID' do
          before(:each) do
            flow.flow_session[:pii_from_user][:same_address_as_id] = 'false'
          end

          it 'leaves the "same_address_as_id" in the flow session as false' do
            step.call
            expect(flow.flow_session[:pii_from_user][:same_address_as_id]).to eq('false')
          end
        end
      end
    end
  end

  describe '#analytics_submitted_event' do
    it 'logs idv_in_person_proofing_residential_address_submitted' do
      expect(step.analytics_submitted_event).to be(
        :idv_in_person_proofing_residential_address_submitted,
      )
    end
  end

  describe '#extra_view_variables' do
    let(:address1) { '123 Fourth St' }
    let(:params) { ActionController::Parameters.new }

    context 'address1 is set' do
      it 'returns extra view variables and updating_address is true' do
        pii_from_user[:address1] = address1

        expect(step.extra_view_variables).to include(
          pii: include(
            address1:,
          ),
          updating_address: true,
        )
      end
    end

    context 'address1 is not set' do
      it 'does not return extra view variables and updating_address is false' do
        expect(step.extra_view_variables[:pii]).not_to include(
          address1:,
        )

        expect(step.extra_view_variables).to include(
          updating_address: false,
        )
      end
    end
  end
end
