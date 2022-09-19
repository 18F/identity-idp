require 'rails_helper'

describe Idv::Steps::InPerson::AddressStep do
  let(:submitted_values) { {} }
  let(:params) { { doc_auth: submitted_values } }
  let(:user) { build(:user) }
  let(:service_provider) { create(:service_provider) }
  let(:controller) do
    instance_double(
      'controller',
      session: { sp: { issuer: service_provider.issuer } },
      params: params,
      current_user: user,
    )
  end

  let(:flow) do
    Idv::Flows::InPersonFlow.new(controller, {}, 'idv/in_person')
  end

  subject(:step) do
    Idv::Steps::InPerson::AddressStep.new(flow)
  end

  describe '#call' do
    context 'with values submitted' do
      let(:address1) { '1 FAKE RD' }
      let(:address2) { 'APT 1B' }
      let(:city) { 'GREAT FALLS' }
      let(:zipcode) { '59010' }
      let(:state) { 'Montana' }
      let(:same_address_as_id) { false }
      let(:submitted_values) do
        {
          address1: address1,
          address2: address2,
          city: city,
          zipcode: zipcode,
          state: state,
          same_address_as_id: same_address_as_id,
        }
      end

      it 'sets values in flow session' do
        Idv::InPerson::AddressForm::ATTRIBUTES.each do |attr|
          expect(flow.flow_session[:pii_from_user]).to_not have_key attr
        end

        step.call

        pii_from_user = flow.flow_session[:pii_from_user]
        expect(pii_from_user[:address1]).to eq address1
        expect(pii_from_user[:address2]).to eq address2
        expect(pii_from_user[:city]).to eq city
        expect(pii_from_user[:zipcode]).to eq zipcode
        expect(pii_from_user[:state]).to eq state
        expect(pii_from_user[:same_address_as_id]).to eq same_address_as_id
      end
    end
  end
end
