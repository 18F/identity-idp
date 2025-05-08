require 'rails_helper'

RSpec.describe DocAuth::Mock::DocAuthMockClient do
  subject(:client) { described_class.new }

  let(:liveness_checking_required) { false }

  let(:instance_id) { 'fake-instance-id' }

  it 'allows doc auth without any external requests' do
    post_front_image_response = client.post_front_image(
      instance_id: instance_id,
      image: DocAuthImageFixtures.document_front_image,
    )
    post_back_image_response = client.post_back_image(
      instance_id: instance_id,
      image: DocAuthImageFixtures.document_back_image,
    )
    get_results_response = client.get_results(
      instance_id: instance_id,
    )

    expect(post_front_image_response.success?).to eq(true)
    expect(post_back_image_response.success?).to eq(true)

    expect(get_results_response.success?).to eq(true)
    expect(get_results_response.pii_from_doc).to eq(
      Pii::StateId.new(
        first_name: 'FAKEY',
        middle_name: nil,
        last_name: 'MCFAKERSON',
        name_suffix: 'JR',
        address1: '1 FAKE RD',
        address2: nil,
        city: 'GREAT FALLS',
        state: 'MT',
        zipcode: '59010-1234',
        dob: '1938-10-06',
        sex: 'male',
        height: 72,
        weight: nil,
        eye_color: nil,
        state_id_number: '1111111111111',
        state_id_jurisdiction: 'ND',
        id_doc_type: 'drivers_license',
        state_id_expiration: '2099-12-31',
        state_id_issued: '2019-12-31',
        issuing_country_code: 'US',
      ),
    )
  end

  context 'when given passport yaml' do
    let(:passport_yaml) { 'needs to be set' }

    let(:post_passport_image_response) do
      client.post_passport_image(
        instance_id: instance_id,
        image: passport_yaml,
      )
    end

    let(:get_results_response) do
      client.get_results(
        instance_id: instance_id,
        passport_submittal: true,
      )
    end

    let(:expected_pii_hash) do
      Pii::Passport.new(
        first_name: 'Joe',
        last_name: 'Dokes',
        middle_name: 'Q',
        dob: '1938-10-06',
        sex: 'Male',
        birth_place: 'birthplace',
        passport_expiration: '2030-03-15',
        issuing_country_code: 'USA',
        # rubocop:disable Layout/LineLength
        mrz: 'P<UTOSAMPLE<<COMPANY<<<<<<<<<<<<<<<<<<<<<<<<ACU1234P<5UTO0003067F4003065<<<<<<<<<<<<<<02',
        # rubocop:enable Layout/LineLength
        passport_issued: '2015-03-15',
        nationality_code: 'USA',
        document_number: '000000',
        id_doc_type: 'passport',
      ).to_h
    end

    context 'for a valid passport' do
      let(:passport_yaml) { DocAuthImageFixtures.passport_passed_yaml.read }

      it 'passes' do
        expect(post_passport_image_response.success?).to eq(true)
        expect(get_results_response.success?).to eq(true)
        expect(get_results_response.pii_from_doc.to_h).to eq(expected_pii_hash)
      end
    end

    context 'when given a passport with a bad MRZ' do
      let(:passport_yaml) { DocAuthImageFixtures.passport_failed_yaml.read }

      it 'fails' do
        expect(post_passport_image_response.success?).to eq(true)
        expect(get_results_response.success?).to eq(true)
        expect(get_results_response.pii_from_doc.to_h).to eq(expected_pii_hash)
      end
    end
  end

  it 'if the document is a YAML file it returns the PII from the YAML file' do
    yaml = <<~YAML
      document:
        first_name: Susan
        last_name: Smith
        middle_name: Q
        name_suffix: 'SR'
        address1: 1 Microsoft Way
        address2: Apt 3
        city: Bayside
        state: NY
        zipcode: '11364'
        dob: 1938-10-06
        sex: 'female'
        height: 66
        state_id_number: '111111111'
        state_id_jurisdiction: ND
        id_doc_type: drivers_license
        state_id_expiration: '2089-12-31'
        state_id_issued: '2009-12-31'
        issuing_country_code: 'CA'
      classification_info:
          Front:
            ClassName: Tribal Identification
    YAML

    client.post_front_image(
      instance_id: instance_id,
      image: yaml,
    )
    client.post_back_image(
      instance_id: instance_id,
      image: yaml,
    )
    get_results_response = client.get_results(
      instance_id: instance_id,
    )

    expect(get_results_response.pii_from_doc).to eq(
      Pii::StateId.new(
        first_name: 'Susan',
        middle_name: 'Q',
        last_name: 'Smith',
        name_suffix: 'SR',
        address1: '1 Microsoft Way',
        address2: 'Apt 3',
        city: 'Bayside',
        state: 'NY',
        zipcode: '11364',
        dob: '1938-10-06',
        sex: 'female',
        height: 66,
        weight: nil,
        eye_color: nil,
        state_id_number: '111111111',
        state_id_jurisdiction: 'ND',
        id_doc_type: 'drivers_license',
        state_id_expiration: '2089-12-31',
        state_id_issued: '2009-12-31',
        issuing_country_code: 'CA',
      ),
    )
    expect(get_results_response.attention_with_barcode?).to eq(false)
  end

  it 'if the document is a YAML file that does not include all PII attributes returns defaults' do
    yaml = <<~YAML
      document:
        first_name: Susan
      classification_info:
          Front:
            ClassName: Tribal Identification
    YAML

    client.post_front_image(
      instance_id: instance_id,
      image: yaml,
    )
    client.post_back_image(
      instance_id: instance_id,
      image: yaml,
    )
    get_results_response = client.get_results(
      instance_id: instance_id,
    )

    expect(get_results_response.pii_from_doc).to eq(
      Pii::StateId.new(
        first_name: 'Susan',
        middle_name: nil,
        last_name: 'MCFAKERSON',
        name_suffix: 'JR',
        address1: '1 FAKE RD',
        address2: nil,
        city: 'GREAT FALLS',
        state: 'MT',
        zipcode: '59010-1234',
        dob: '1938-10-06',
        sex: 'male',
        height: 72,
        weight: nil,
        eye_color: nil,
        state_id_number: '1111111111111',
        state_id_jurisdiction: 'ND',
        id_doc_type: 'drivers_license',
        state_id_expiration: '2099-12-31',
        state_id_issued: '2019-12-31',
        issuing_country_code: 'US',
      ),
    )
    expect(get_results_response.attention_with_barcode?).to eq(false)
  end

  it 'if the document is a YAML file with unsupported document type it returns error' do
    yaml = <<~YAML
      classification_info:
          Front:
            ClassName: Tribal Identification
          Back:
            ClassName: Tribal Identification
    YAML

    client.post_front_image(
      instance_id: instance_id,
      image: yaml,
    )
    client.post_back_image(
      instance_id: instance_id,
      image: yaml,
    )
    get_results_response = client.get_results(
      instance_id: instance_id,
    )
    expect(get_results_response.attention_with_barcode?).to eq(false)
    errors = get_results_response.errors
    expect(errors.keys).to contain_exactly(:general, :front, :back, :hints)
    expect(errors[:general]).to contain_exactly(DocAuth::Errors::DOC_TYPE_CHECK)
    expect(errors[:front]).to contain_exactly(DocAuth::Errors::CARD_TYPE)
    expect(errors[:back]).to contain_exactly(DocAuth::Errors::CARD_TYPE)
    expect(errors[:hints]).to eq(true)
    expect(get_results_response.extra[:classification_info]).to include(:Front, :Back)
  end

  it 'allows responses to be mocked' do
    response = DocAuth::Response.new(
      success: true,
      errors: nil,
      exception: nil,
      extra: { vendor: 'Mock' },
    )
    DocAuth::Mock::DocAuthMockClient.mock_response!(method: :post_front_image, response: response)

    expect(
      described_class.new.post_front_image(
        image: DocAuthImageFixtures.document_front_image,
        instance_id: 'fake-instance-id',
      ),
    ).to eq(response)

    described_class.reset!

    expect(
      described_class.new.post_front_image(
        image: DocAuthImageFixtures.document_front_image,
        instance_id: 'fake-instance-id',
      ),
    ).to_not eq(response)
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
      image_source: DocAuth::ImageSources::UNKNOWN,
    )

    expect(post_images_response).to be_a(DocAuth::Response)
  end

  describe 'selfie check performed flag' do
    context 'when a liveness check is required' do
      let(:liveness_checking_required) { true }

      image = <<~YAML
        portrait_match_results:
          FaceMatchResult: Pass
          FaceErrorMessage: 'Successful. Liveness: Live'
        doc_auth_result: Passed
        failed_alerts: []
      YAML

      image_no_setting = <<~YAML
        doc_auth_result: Passed
        failed_alerts: []
      YAML

      it 'sets selfie_check_performed to true' do
        response = client.post_images(
          front_image: image,
          back_image: image,
          liveness_checking_required: liveness_checking_required,
          selfie_image: image,
        )

        expect(response.selfie_check_performed?).to be(true)
        expect(response.extra[:portrait_match_results]).to be_present
      end

      it 'returns selfie status with default setting' do
        response = client.post_images(
          front_image: image_no_setting,
          back_image: image_no_setting,
          liveness_checking_required: liveness_checking_required,
          selfie_image: image_no_setting,
        )

        expect(response.selfie_check_performed?).to be(true)
        expect(response.selfie_status).to eq(:success)
        expect(response.extra[:portrait_match_results]).to be_nil
      end
    end

    context 'when a liveness check is not required' do
      let(:liveness_checking_required) { false }

      image = <<~YAML
        doc_auth_result: Passed
        failed_alerts: []
      YAML

      it 'sets selfie_check_performed to false' do
        response = client.post_images(
          front_image: image,
          back_image: image,
          liveness_checking_required: liveness_checking_required,
        )

        expect(response.selfie_check_performed?).to be(false)
        expect(response.extra[:portrait_match_results]).to be_nil
      end
    end
  end

  describe 'generate response for failure indicating http status' do
    it 'generate network error response for status 500 when post image' do
      image = <<-YAML
      http_status:
        front: 500
        back: 500
      YAML
      response = client.post_front_image(
        image: image,
        instance_id: nil,
      )
      expect(response).to be_a(DocAuth::Response)
      expect(response.success?).to eq(false)
      expect(response.errors).to eq(general: ['network'])
    end

    it 'generate network error response for status 500 when get result' do
      image = <<~YAML
        http_status:
          result: 500
      YAML
      client.post_back_image(
        image: image,
        instance_id: nil,
      )
      response = client.get_results(
        instance_id: nil,
      )
      expect(response).to be_a(DocAuth::Response)
      expect(response.success?).to eq(false)
      expect(response.errors).to eq(general: ['network'])
    end

    it 'generate correct error for status 440' do
      image = <<~YAML
        http_status:
          front: 440
      YAML
      response = client.post_front_image(
        image: image,
        instance_id: nil,
      )
      expect(response).to be_a(DocAuth::Response)
      expect(response.success?).to eq(false)
      expect(response.errors).to eq(
        { general: [DocAuth::Errors::IMAGE_SIZE_FAILURE],
          front: [DocAuth::Errors::IMAGE_SIZE_FAILURE_FIELD] },
      )
    end
  end

  context 'liveness checking is required and doc_auth_result is passed' do
    let(:liveness_checking_required) { true }

    describe 'when sending a selfie image that is successful (both live and a match)' do
      it 'returns a success response' do
        image = <<~YAML
          portrait_match_results:
            FaceMatchResult: Pass
            FaceErrorMessage: 'Successful. Liveness: Live'
          doc_auth_result: Passed
          failed_alerts: []
        YAML

        post_images_response = client.post_images(
          front_image: image,
          back_image: image,
          selfie_image: image,
          liveness_checking_required: liveness_checking_required,
        )

        expect(post_images_response.success?).to eq(true)
        expect(post_images_response.extra[:portrait_match_results]).to eq(
          {
            FaceMatchResult: 'Pass', FaceErrorMessage: 'Successful. Liveness: Live'
          },
        )
        expect(post_images_response.errors).to be_empty
      end
    end

    # TODO fix this set of tests, this looks like something broken with error generation?
    #      NoMethodError:
    # undefined method `empty?' for nil
    # ./app/services/doc_auth/error_result.rb:33:in `to_h'
    describe 'when sending a failing selfie yml' do
      context 'liveness check fails due to being determined to not be live' do
        it 'returns a failure response' do
          image = <<~YAML
            portrait_match_results:
              FaceMatchResult: Fail
              FaceErrorMessage: 'Liveness: NotLive'
            doc_auth_result: Passed
            failed_alerts: []
          YAML

          post_images_response = client.post_images(
            front_image: image,
            back_image: image,
            selfie_image: image,
            liveness_checking_required: liveness_checking_required,
          )

          expect(post_images_response.success?).to eq(false)
          expect(post_images_response.extra[:portrait_match_results]).to eq(
            {
              FaceMatchResult: 'Fail', FaceErrorMessage: 'Liveness: NotLive'
            },
          )

          errors = post_images_response.errors
          expect(errors.keys).to contain_exactly(:general, :hints, :selfie)
          expect(errors[:selfie]).to contain_exactly(
            DocAuth::Errors::SELFIE_FAILURE,
          )
        end
      end

      context 'liveness check fails due to poor quality' do
        it 'returns a failure response' do
          image = <<~YAML
            portrait_match_results:
              FaceMatchResult: Fail
              FaceErrorMessage: 'Liveness: PoorQuality'
            doc_auth_result: Passed
            failed_alerts: []
          YAML

          post_images_response = client.post_images(
            front_image: image,
            back_image: image,
            selfie_image: image,
            liveness_checking_required: liveness_checking_required,
          )

          expect(post_images_response.success?).to eq(false)
          expect(post_images_response.extra[:portrait_match_results]).to eq(
            {
              FaceMatchResult: 'Fail', FaceErrorMessage: 'Liveness: PoorQuality'
            },
          )

          errors = post_images_response.errors
          expect(errors.keys).to contain_exactly(:general, :hints, :selfie)
          expect(errors[:selfie]).to contain_exactly(
            DocAuth::Errors::SELFIE_FAILURE,
          )
        end
      end

      context 'assessed to be live but face match result fails' do
        it 'returns a failure response' do
          image = <<~YAML
            portrait_match_results:
              FaceMatchResult: Fail
              FaceErrorMessage: 'Successful. Liveness: Live'
            doc_auth_result: Passed
            failed_alerts: []
          YAML
          post_images_response = client.post_images(
            front_image: image,
            back_image: image,
            selfie_image: image,
            liveness_checking_required: liveness_checking_required,
          )

          expect(post_images_response.success?).to eq(false)
          expect(post_images_response.extra[:portrait_match_results]).to eq(
            {
              FaceMatchResult: 'Fail', FaceErrorMessage: 'Successful. Liveness: Live'
            },
          )

          errors = post_images_response.errors
          expect(errors.keys).to contain_exactly(:general, :back, :front, :hints, :selfie)
          expect(errors[:selfie]).to contain_exactly(
            DocAuth::Errors::SELFIE_FAILURE,
          )
        end
      end
    end
  end
end
