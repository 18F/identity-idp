require 'rails_helper'

RSpec.describe Idv::PiiValidator do
  subject(:pii_validator) { described_class.new(client_response, extra, fake_analytics) }

  let(:client_response) do
    DocAuth::Response.new(
      success: true,
      pii_from_doc:,
    )
  end

  let(:pii_from_doc) do
    Pii::StateId.new(
      first_name: nil,
      last_name: nil,
      middle_name: nil,
      name_suffix: nil,
      address1: nil,
      address2: nil,
      city: nil,
      state: nil,
      zipcode: nil,
      dob: nil,
      sex: nil,
      height: nil,
      weight: nil,
      eye_color: nil,
      state_id_expiration: nil,
      state_id_issued: nil,
      state_id_jurisdiction: nil,
      state_id_number: nil,
      state_id_type: nil,
      issuing_country_code: nil,
    )
  end

  let(:extra) do
    {
      remaining_submit_attempts: 1,
      flow_path: :standard,
      liveness_checking_required: false,
      submit_attempts: 1,
    }
  end
  let(:fake_analytics) { FakeAnalytics.new }

  describe '#doc_auth_form_response' do
    before { stub_analytics }

    subject(:response) { pii_validator.doc_auth_form_response }

    it 'returns a DocPiiForm with the pii and logs the sumission' do
      expect(response.pii_from_doc).to eq(pii_from_doc.to_h)
      expect(fake_analytics).to have_logged_event('IdV: doc auth image upload vendor pii validation')
    end
  end
end
