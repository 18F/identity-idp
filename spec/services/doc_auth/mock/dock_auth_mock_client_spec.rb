require 'rails_helper'

RSpec.describe DocAuth::Mock::DocAuthMockClient do
  subject(:client) { described_class.new }

  it 'implements the same public methods as the real Acuant client' do
    expect(
      described_class.instance_methods.sort,
    ).to eq(
      DocAuth::Acuant::AcuantClient.instance_methods.sort,
    )
  end

  it 'allows doc auth without any external requests' do
    create_document_response = client.create_document
    instance_id = create_document_response.instance_id
    post_front_image_response = client.post_front_image(
      instance_id: instance_id,
      image: DocAuthImageFixtures.document_front_image,
    )
    post_back_image_response = client.post_back_image(
      instance_id: instance_id,
      image: DocAuthImageFixtures.document_back_image,
    )
    get_results_response = client.get_results(instance_id: instance_id, liveness_enabled: false)

    selfie_response = client.post_selfie(
      instance_id: instance_id,
      image: DocAuthImageFixtures.selfie_image,
    )

    expect(create_document_response.success?).to eq(true)
    expect(create_document_response.instance_id).to_not be_blank

    expect(post_front_image_response.success?).to eq(true)
    expect(post_back_image_response.success?).to eq(true)

    expect(get_results_response.success?).to eq(true)
    expect(get_results_response.pii_from_doc).to eq(
      first_name: 'FAKEY',
      middle_name: nil,
      last_name: 'MCFAKERSON',
      address1: '1 FAKE RD',
      address2: nil,
      city: 'GREAT FALLS',
      state: 'MT',
      zipcode: '59010',
      dob: '1938-10-06',
      state_id_number: '1111111111111',
      state_id_jurisdiction: 'ND',
      state_id_type: 'drivers_license',
      state_id_expiration: '2099-12-31',
      phone: nil,
    )

    expect(selfie_response.success?).to eq(true)
    expect(selfie_response.attention_with_barcode?).to eq(false)
  end

  it 'if the document is a YAML file it returns the PII from the YAML file' do
    yaml = <<~YAML
      document:
        first_name: Susan
        last_name: Smith
        middle_name: Q
        address1: 1 Microsoft Way
        address2: Apt 3
        city: Bayside
        state: NY
        zipcode: '11364'
        dob: 1938-10-06
        state_id_number: '111111111'
        state_id_jurisdiction: ND
        state_id_type: drivers_license
    YAML

    create_document_response = client.create_document
    instance_id = create_document_response.instance_id
    client.post_front_image(
      instance_id: instance_id,
      image: yaml,
    )
    client.post_back_image(
      instance_id: instance_id,
      image: yaml,
    )
    get_results_response = client.get_results(
      instance_id: create_document_response.instance_id,
      liveness_enabled: false,
    )

    expect(get_results_response.pii_from_doc).to eq(
      first_name: 'Susan',
      middle_name: 'Q',
      last_name: 'Smith',
      address1: '1 Microsoft Way',
      address2: 'Apt 3',
      city: 'Bayside',
      state: 'NY',
      zipcode: '11364',
      dob: '1938-10-06',
      state_id_number: '111111111',
      state_id_jurisdiction: 'ND',
      state_id_type: 'drivers_license',
    )
    expect(get_results_response.attention_with_barcode?).to eq(false)
  end

  it 'allows responses to be mocked' do
    described_class.mock_response!(method: :create_document, response: 'Create doc test')

    expect(described_class.new.create_document).to eq('Create doc test')

    described_class.reset!

    expect(described_class.new.create_document).to_not eq('Create doc test')
  end

  context 'when checking results gives a failure' do
    before do
      DocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :get_results,
        response: DocAuth::Response.new(
          success: false,
          errors: { back_image: 'blurry' },
        ),
      )
    end

    it 'returns a failure response if the results failed' do
      post_images_response = client.post_images(
        front_image: DocAuthImageFixtures.document_front_image,
        back_image: DocAuthImageFixtures.document_back_image,
        selfie_image: nil,
      )

      expect(post_images_response.success?).to eq(false)
      expect(post_images_response.errors).to eq(back_image: 'blurry')
      expect(post_images_response.attention_with_barcode?).to eq(false)
    end
  end

  it 'ignores image_sources argument' do
    post_images_response = client.post_images(
      front_image: DocAuthImageFixtures.document_front_image,
      back_image: DocAuthImageFixtures.document_back_image,
      selfie_image: nil,
      image_source: DocAuth::ImageSources::UNKNOWN,
    )

    expect(post_images_response).to be_a(DocAuth::Response)
  end
end
