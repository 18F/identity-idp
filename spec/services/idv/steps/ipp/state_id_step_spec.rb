require 'rails_helper'

describe Idv::Steps::Ipp::StateIdStep do
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
    Idv::Steps::Ipp::StateIdStep.new(flow)
  end

  describe '#call' do
    context 'with values submitted' do
      let(:first_name) { 'Natalya' }
      let(:last_name) { 'Rostova' }
      let(:dob) { '1980-01-01' }
      let(:state_id_jurisdiction) { 'Nevada' }
      let(:state_id_number) { 'ABC123234' }
      let(:submitted_values) do
        {
          first_name: first_name,
          last_name: last_name,
          dob: dob,
          state_id_jurisdiction: state_id_jurisdiction,
          state_id_number: state_id_number,
        }
      end

      it 'sets values in flow session' do
        Idv::StateIdForm::ATTRIBUTES.each do |attr|
          expect(flow.flow_session[:pii_from_user]).to_not have_key attr
        end

        step.call

        pii_from_user = flow.flow_session[:pii_from_user]
        expect(pii_from_user[:first_name]).to eq first_name
        expect(pii_from_user[:last_name]).to eq last_name
        expect(pii_from_user[:dob]).to eq dob
        expect(pii_from_user[:state_id_jurisdiction]).to eq state_id_jurisdiction
        expect(pii_from_user[:state_id_number]).to eq state_id_number
      end
    end
  end
end
