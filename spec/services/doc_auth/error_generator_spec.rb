require 'rails_helper'

RSpec.describe DocAuth::ErrorGenerator do
  let(:warn_notifier) { instance_double('Proc') }

  let(:config) do
    DocAuth::LexisNexis::Config.new(
      warn_notifier: warn_notifier,
    )
  end

  let(:unsupported_classification_details) do
    { ClassName: 'LibraryCard',
      Issue: '2006',
      IssueType: 'ePassport',
      Name: 'United States (USA) ePassport',
      IssuerCode: 'USA',
      IssuerName: 'United States',
      IssuerType: 'Library' }
  end
  let(:unknown_classification_details) do
    { ClassName: 'Unknown',
      Issue: nil,
      IssueType: nil,
      Name: 'Unknown',
      IssuerCode: nil,
      IssuerName: nil }
  end
  let(:vhic_classification_details) do
    { ClassName: 'Identification Card',
      Issue: '2020',
      IssueType: 'Veteran Health Identification Card',
      Name: 'United States (USA) Veteran Health Identification Card',
      IssuerCode: 'USA',
      IssuerName: 'United States',
      IssuerType: 'HHS' }
  end

  let(:liveness_enabled) { nil }
  let(:face_match_result) { 'Pass' }
  let(:portrait_match_results) do
    {
      FaceMatchResult: face_match_result,
    }
  end

  let(:result_code_invalid) { false }

  def build_error_info(
    doc_result: nil,
    passed: [],
    failed: [],
    image_metrics: {},
    classification_info: []
  )
    {
      conversation_id: 31000406181234,
      reference: 'Reference1',
      liveness_enabled: liveness_enabled,
      vendor: 'Test',
      transaction_reason_code: 'testing',
      doc_auth_result: doc_result,
      processed_alerts: {
        passed: passed,
        failed: failed,
      },
      alert_failure_count: failed&.count.to_i,
      portrait_match_results: portrait_match_results,
      image_metrics: image_metrics,
      classification_info: classification_info,
      result_code_invalid: result_code_invalid,
    }
  end

  context 'The correct errors are delivered when' do
    let(:result_code_invalid) { true }
    context 'when is attention' do
      let(:result_code_invalid) { false }
      it 'DocAuthResult is Attention with barcode' do
        # noop - because we check for success or attn with barcode
        # before entering the error generator, this case should never happen.
      end

      it 'DocAuthResult is Attention of Barcode Read and general selfie error' do
        error_info = build_error_info(
          doc_result: 'Attention',
          failed: [{ name: '2D Barcode Read', result: 'Attention' }],
        )
        error_info[:liveness_enabled] = true
        # Selfie not match ID
        error_info[:portrait_match_results] = {
          FaceMatchResult: 'Fail',
          FaceErrorMessage: 'Successful. Liveness: Live',
        }
        output = described_class.new(config).generate_doc_auth_errors(error_info)
        expect(output.keys).to contain_exactly(:general, :back, :front, :selfie, :hints)
        expect(output[:general]).to contain_exactly(DocAuth::Errors::SELFIE_FAILURE)
        expect(output[:front]).to contain_exactly(DocAuth::Errors::MULTIPLE_FRONT_ID_FAILURES)
        expect(output[:back]).to contain_exactly(DocAuth::Errors::MULTIPLE_BACK_ID_FAILURES)
        expect(output[:selfie]).to contain_exactly(DocAuth::Errors::SELFIE_FAILURE)
        expect(output[:hints]).to eq(false)
      end

      it 'DocAuthResult is Attention with unknown alert' do
        error_info = build_error_info(
          doc_result: 'Attention',
          failed: [{ name: 'Unknown Alert', result: 'Attention' }],
        )

        expect(warn_notifier).to receive(:call)
          .with(hash_including(:response_info, :message)).twice

        output = described_class.new(config).generate_doc_auth_errors(error_info)

        expect(output.keys).to contain_exactly(:general, :front, :back, :hints)
        expect(output[:general]).to contain_exactly(DocAuth::Errors::GENERAL_ERROR)
        expect(output[:back]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
        expect(output[:back]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
        expect(output[:hints]).to eq(true)
      end
    end
    it 'DocAuthResult is Unknown and general selfie error' do
      error_info = build_error_info(
        doc_result: 'Unknown',
        failed: [{ name: 'Visible Pattern', result: 'Failed' }],
      )
      error_info[:liveness_enabled] = true
      # Selfie not match ID
      error_info[:portrait_match_results] = {
        FaceMatchResult: 'Fail',
        FaceErrorMessage: 'Successful. Liveness: Live',
      }
      output = described_class.new(config).generate_doc_auth_errors(error_info)
      expect(output.keys).to contain_exactly(:general, :front, :back, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::ID_NOT_VERIFIED)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(output[:hints]).to eq(true)
    end

    it 'DocAuthResult is Failed' do
      error_info = build_error_info(
        doc_result: 'Failed',
        failed: [{ name: 'Visible Pattern', result: 'Failed' }],
      )

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :front, :back, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::ID_NOT_VERIFIED)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(output[:hints]).to eq(true)
    end

    it 'DocAuthResult is Failed with single alert with a side' do
      error_info = build_error_info(
        doc_result: 'Failed',
        failed: [{ name: 'Visible Pattern', result: 'Failed', side: 'front' }],
      )

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :front, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::ID_NOT_VERIFIED)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(output[:hints]).to eq(true)
    end

    it 'DocAuthResult is Failed with multiple different alerts' do
      error_info = build_error_info(
        doc_result: 'Failed',
        failed: [
          { name: '2D Barcode Read', result: 'Attention' },
          { name: 'Visible Pattern', result: 'Failed' },
        ],
      )

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :front, :back, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::GENERAL_ERROR)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(output[:hints]).to eq(true)
    end

    it 'DocAuthResult is Failed with multiple id alerts' do
      error_info = build_error_info(
        doc_result: 'Failed',
        failed: [
          { name: 'Expiration Date Valid', result: 'Attention' },
          { name: 'Full Name Crosscheck', result: 'Failed' },
        ],
      )

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :front, :back, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::GENERAL_ERROR)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(output[:hints]).to eq(true)
    end

    it 'DocAuthResult is Failed with multiple front alerts' do
      error_info = build_error_info(
        doc_result: 'Failed',
        failed: [
          { name: 'Photo Printing', result: 'Attention' },
          { name: 'Visible Photo Characteristics', result: 'Failed' },
        ],
      )

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :front, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::MULTIPLE_FRONT_ID_FAILURES)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(output[:hints]).to eq(true)
    end

    it 'DocAuthResult is Failed with multiple back alerts' do
      error_info = build_error_info(
        doc_result: 'Failed',
        failed: [
          { name: '2D Barcode Read', result: 'Attention' },
          { name: '2D Barcode Content', result: 'Failed' },
        ],
      )

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :back, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::MULTIPLE_BACK_ID_FAILURES)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(output[:hints]).to eq(true)
    end

    it 'DocAuthResult is Failed with an unknown alert' do
      error_info = build_error_info(
        doc_result: 'Failed',
        failed: [{ name: 'Not a known alert', result: 'Failed' }],
      )

      expect(warn_notifier).to receive(:call)
        .with(hash_including(:response_info, :message)).twice

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :front, :back, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::GENERAL_ERROR)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(output[:hints]).to eq(true)
    end

    it 'DocAuthResult is Failed with multiple alerts including an unknown' do
      error_info = build_error_info(
        doc_result: 'Failed',
        failed: [
          { name: 'Not a known alert', result: 'Failed' },
          { name: 'Birth Date Crosscheck', result: 'Failed' },
        ],
      )

      expect(warn_notifier).to receive(:call)
        .with(hash_including(:response_info, :message, :unknown_alerts)).once

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :front, :back, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::BIRTH_DATE_CHECKS)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(output[:hints]).to eq(true)
    end

    it 'DocAuthResult is Failed with an unknown passed alert' do
      error_info = build_error_info(
        doc_result: 'Failed',
        passed: [{ name: 'Not a known alert', result: 'Passed' }],
        failed: [{ name: 'Birth Date Crosscheck', result: 'Failed' }],
      )

      expect(warn_notifier).to receive(:call)
        .with(hash_including(:response_info, :message, :unknown_alerts)).once

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :front, :back, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::BIRTH_DATE_CHECKS)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(output[:hints]).to eq(true)
    end

    it 'DocAuthResult is failed with unsupported doc type' do
      error_info = build_error_info(
        doc_result: 'Failed',
        passed: [{ name: 'Not a known alert', result: 'Passed' }],
        failed: [{ name: 'Birth Date Crosscheck', result: 'Failed' }],
        classification_info: { Back: unknown_classification_details,
                               Front: unsupported_classification_details },
      )

      expect(warn_notifier).to receive(:call)
        .with(hash_including(:response_info, :message, :unknown_alerts)).once

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :front, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::DOC_TYPE_CHECK)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::CARD_TYPE)
      expect(output[:hints]).to eq(true)
    end

    it 'DocAuthResult is Failed with unknown alert and general selfie error' do
      error_info = build_error_info(
        doc_result: 'Failed',
        failed: [{ name: 'Unknown alert', result: 'Failed' }],
      )
      error_info[:liveness_enabled] = true
      # Selfie not match ID
      error_info[:portrait_match_results] = {
        FaceMatchResult: 'Fail',
        FaceErrorMessage: 'Successful. Liveness: Live',
      }
      expect(warn_notifier).to receive(:call)
        .with(hash_including(:response_info, :message)).twice
      output = described_class.new(config).generate_doc_auth_errors(error_info)
      expect(output.keys).to contain_exactly(:general, :front, :back, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::GENERAL_ERROR)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(output[:hints]).to eq(true)
    end

    it 'DocAuthResult is Failed with known alert and specific selfie no liveness error' do
      error_info = build_error_info(
        doc_result: 'Failed',
        failed: [{ name: 'Visible Pattern', result: 'Failed' }],
      )
      error_info[:liveness_enabled] = true
      # Selfie not match ID
      error_info[:portrait_match_results] = {
        FaceMatchResult: 'Fail',
        FaceErrorMessage: 'Liveness: NotLive',
      }
      output = described_class.new(config).generate_doc_auth_errors(error_info)
      expect(output.keys).to contain_exactly(:general, :front, :back, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::ID_NOT_VERIFIED)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(output[:hints]).to eq(true)
    end

    it 'DocAuthResult is success with unsupported doc type' do
      error_info = build_error_info(
        doc_result: 'Passed',
        passed: [{ name: 'Not a known alert', result: 'Passed' }],
        failed: [],
        classification_info: { Back: unknown_classification_details,
                               Front: unsupported_classification_details },
      )

      expect(warn_notifier).to receive(:call)
        .with(hash_including(:response_info, :message, :unknown_alerts)).once

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :front, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::DOC_TYPE_CHECK)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::CARD_TYPE)
      expect(output[:hints]).to eq(true)
    end

    it 'DocAuthResult is success with VHIC' do
      error_info = build_error_info(
        doc_result: 'Passed',
        passed: [{ name: 'Not a known alert', result: 'Passed' }],
        failed: [],
        classification_info: { Back: vhic_classification_details,
                               Front: vhic_classification_details },
      )

      expect(warn_notifier).to receive(:call)
        .with(hash_including(:response_info, :message, :unknown_alerts)).once

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :front, :back, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::DOC_TYPE_CHECK)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::CARD_TYPE)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::CARD_TYPE)
      expect(output[:hints]).to eq(true)
    end

    it 'DocAuthResult is failed with unknown doc type' do
      error_info = build_error_info(
        doc_result: 'Failed',
        failed: [
          { name: 'Not a known alert', result: 'Failed' },
        ],
        classification_info: { Front: unknown_classification_details },
      )

      expect(warn_notifier).to receive(:call)
        .with(hash_including(:response_info, :message)).twice

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :front, :back, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::GENERAL_ERROR)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(output[:hints]).to eq(true)
    end

    it 'DocAuthResult is success with an unknown alert' do
      error_info = build_error_info(
        doc_result: 'Passed',
        failed: [{ name: 'Not a known alert', result: 'Failed' }],
      )
      expect(warn_notifier).to receive(:call)
        .with(hash_including(:response_info, :message)).twice

      # this is a fall back result, we cannot generate error but the generator is called
      # which should not happen
      output = described_class.new(config).generate_doc_auth_errors(error_info)
      expect(output.keys).to contain_exactly(:general, :front, :back, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::GENERAL_ERROR)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(output[:hints]).to eq(true)
    end
    it 'DocAuthResult is success with general selfie error' do
      error_info = build_error_info(
        doc_result: 'Passed',
        failed: [],
      )
      error_info[:liveness_enabled] = true
      # Selfie not match ID
      error_info[:portrait_match_results] = {
        FaceMatchResult: 'Fail',
        FaceErrorMessage: 'Successful. Liveness: Live',
      }

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :front, :back, :hints, :selfie)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::SELFIE_FAILURE)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::MULTIPLE_FRONT_ID_FAILURES)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::MULTIPLE_BACK_ID_FAILURES)
      expect(output[:selfie]).to contain_exactly(DocAuth::Errors::SELFIE_FAILURE)
      expect(output[:hints]).to eq(false)
    end

    it 'DocAuthResult is success with specific selfie no liveness error' do
      error_info = build_error_info(
        doc_result: 'Passed',
        failed: [],
      )
      error_info[:liveness_enabled] = true
      # Selfie not match ID
      error_info[:portrait_match_results] = {
        FaceMatchResult: 'Fail',
        FaceErrorMessage: 'Liveness: NotLive',
      }

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :hints, :selfie)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::SELFIE_NOT_LIVE_OR_POOR_QUALITY)
      expect(output[:selfie]).to contain_exactly(DocAuth::Errors::SELFIE_FAILURE)
      expect(output[:hints]).to eq(false)
    end

    it 'DocAuthResult is success with specific selfie liveness quality error' do
      error_info = build_error_info(
        doc_result: 'Passed',
        failed: [],
      )
      error_info[:liveness_enabled] = true
      # Selfie not match ID
      error_info[:portrait_match_results] = {
        FaceMatchResult: 'Fail',
        FaceErrorMessage: 'Liveness: PoorQuality',
      }

      output = described_class.new(config).generate_doc_auth_errors(error_info)
      expect(output.keys).to contain_exactly(:general, :hints, :selfie)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::SELFIE_NOT_LIVE_OR_POOR_QUALITY)
      expect(output[:selfie]).to contain_exactly(DocAuth::Errors::SELFIE_FAILURE)
      expect(output[:hints]).to eq(false)
    end

    it 'DocAuthResult is success with alert and general selfie error' do
      error_info = build_error_info(
        doc_result: 'Passed',
        failed: [{ name: 'Visible Pattern', result: 'Failed' }],
      )
      error_info[:liveness_enabled] = true
      # Selfie not match ID
      error_info[:portrait_match_results] = {
        FaceMatchResult: 'Fail',
        FaceErrorMessage: 'Successful. Liveness: Live',
      }

      output = described_class.new(config).generate_doc_auth_errors(error_info)
      expect(output.keys).to contain_exactly(:general, :front, :back, :hints, :selfie)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::SELFIE_FAILURE)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::MULTIPLE_FRONT_ID_FAILURES)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::MULTIPLE_BACK_ID_FAILURES)
      expect(output[:selfie]).to contain_exactly(DocAuth::Errors::SELFIE_FAILURE)
      expect(output[:hints]).to eq(false)
    end

    it 'DocAuthResult is success with unknown alert and general selfie error' do
      error_info = build_error_info(
        doc_result: 'Passed',
        failed: [{ name: 'Unknown alert', result: 'Failed' }],
      )
      error_info[:liveness_enabled] = true
      # Selfie not match ID
      error_info[:portrait_match_results] = {
        FaceMatchResult: 'Fail',
        FaceErrorMessage: 'Successful. Liveness: Live',
      }
      expect(warn_notifier).to receive(:call)
        .with(hash_including(:response_info, :message)).once
      output = described_class.new(config).generate_doc_auth_errors(error_info)
      expect(output.keys).to contain_exactly(:general, :front, :back, :hints, :selfie)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::SELFIE_FAILURE)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::MULTIPLE_FRONT_ID_FAILURES)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::MULTIPLE_BACK_ID_FAILURES)
      expect(output[:selfie]).to contain_exactly(DocAuth::Errors::SELFIE_FAILURE)
      expect(output[:hints]).to eq(false)
    end

    it 'DocAuthResult is success with alert and specific no liveness error' do
      error_info = build_error_info(
        doc_result: 'Passed',
        failed: [{ name: 'Visible Pattern', result: 'Failed' }],
      )
      error_info[:liveness_enabled] = true
      # Selfie not match ID
      error_info[:portrait_match_results] = {
        FaceMatchResult: 'Fail',
        FaceErrorMessage: 'Liveness: NotLive',
      }

      output = described_class.new(config).generate_doc_auth_errors(error_info)
      expect(output.keys).to contain_exactly(:general, :hints, :selfie)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::SELFIE_NOT_LIVE_OR_POOR_QUALITY)
      expect(output[:selfie]).to contain_exactly(DocAuth::Errors::SELFIE_FAILURE)
      expect(output[:hints]).to eq(false)
    end

    it 'DocAuthResult is success with alert and specific liveness quality error' do
      error_info = build_error_info(
        doc_result: 'Passed',
        failed: [{ name: 'Visible Pattern', result: 'Failed' }],
      )
      error_info[:liveness_enabled] = true
      # Selfie not match ID
      error_info[:portrait_match_results] = {
        FaceMatchResult: 'Fail',
        FaceErrorMessage: 'Liveness: PoorQuality',
      }

      output = described_class.new(config).generate_doc_auth_errors(error_info)
      expect(output.keys).to contain_exactly(:general, :hints, :selfie)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::SELFIE_NOT_LIVE_OR_POOR_QUALITY)
      expect(output[:selfie]).to contain_exactly(DocAuth::Errors::SELFIE_FAILURE)
      expect(output[:hints]).to eq(false)
    end
  end

  context 'The correct errors are delivered for image metrics when' do
    let(:metrics) do
      {
        front: {
          'HorizontalResolution' => 300,
          'VerticalResolution' => 300,
          'SharpnessMetric' => 50,
          'GlareMetric' => 50,
        },
        back: {
          'HorizontalResolution' => 300,
          'VerticalResolution' => 300,
          'SharpnessMetric' => 50,
          'GlareMetric' => 50,
        },
      }
    end

    it 'front image HDPI is too low' do
      metrics[:front]['HorizontalResolution'] = 250
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :front, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::DPI_LOW_ONE_SIDE)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::DPI_LOW_FIELD)
      expect(output[:hints]).to eq(false)
    end

    it 'front image VDPI is too low' do
      metrics[:front]['VerticalResolution'] = 250
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :front, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::DPI_LOW_ONE_SIDE)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::DPI_LOW_FIELD)
      expect(output[:hints]).to eq(false)
    end

    it 'back image HDPI is too low' do
      metrics[:back]['HorizontalResolution'] = 250
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :back, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::DPI_LOW_ONE_SIDE)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::DPI_LOW_FIELD)
      expect(output[:hints]).to eq(false)
    end

    it 'front and back image DPI is too low' do
      metrics[:front]['HorizontalResolution'] = 250
      metrics[:back]['VerticalResolution'] = 250
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :front, :back, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::DPI_LOW_BOTH_SIDES)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::DPI_LOW_FIELD)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::DPI_LOW_FIELD)
      expect(output[:hints]).to eq(false)
    end

    it 'front image sharpness is too low' do
      metrics[:front]['SharpnessMetric'] = 25
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :front, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::SHARP_LOW_ONE_SIDE)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::SHARP_LOW_FIELD)
      expect(output[:hints]).to eq(false)
    end

    it 'back image sharpness is too low' do
      metrics[:back]['SharpnessMetric'] = 25
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :back, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::SHARP_LOW_ONE_SIDE)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::SHARP_LOW_FIELD)
      expect(output[:hints]).to eq(false)
    end

    it 'both images sharpness is too low' do
      metrics[:front]['SharpnessMetric'] = 25
      metrics[:back]['SharpnessMetric'] = 25
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :front, :back, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::SHARP_LOW_BOTH_SIDES)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::SHARP_LOW_FIELD)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::SHARP_LOW_FIELD)
      expect(output[:hints]).to eq(false)
    end

    it 'both images sharpness is too low' do
      metrics[:front].delete('SharpnessMetric')
      metrics[:back]['SharpnessMetric'] = 25
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :back, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::SHARP_LOW_ONE_SIDE)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::SHARP_LOW_FIELD)
      expect(output[:hints]).to eq(false)
    end

    it 'front image glare is too low' do
      metrics[:front]['GlareMetric'] = 25
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :front, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::GLARE_LOW_ONE_SIDE)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::GLARE_LOW_FIELD)
      expect(output[:hints]).to eq(false)
    end

    it 'back image glare is too low' do
      metrics[:back]['GlareMetric'] = 25
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :back, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::GLARE_LOW_ONE_SIDE)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::GLARE_LOW_FIELD)
      expect(output[:hints]).to eq(false)
    end

    it 'both images glare is too low' do
      metrics[:front]['GlareMetric'] = 25
      metrics[:back]['GlareMetric'] = 25
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :front, :back, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::GLARE_LOW_BOTH_SIDES)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::GLARE_LOW_FIELD)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::GLARE_LOW_FIELD)
      expect(output[:hints]).to eq(false)
    end

    it 'both images glare is too low' do
      metrics[:front].delete('GlareMetric')
      metrics[:back]['GlareMetric'] = 25
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :back, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::GLARE_LOW_ONE_SIDE)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::GLARE_LOW_FIELD)
      expect(output[:hints]).to eq(false)
    end

    it 'both images have different problems' do
      metrics[:front]['GlareMetric'] = 20
      metrics[:back]['SharpnessMetric'] = 25
      error_info = build_error_info(image_metrics: metrics)

      output = described_class.new(config).generate_doc_auth_errors(error_info)

      expect(output.keys).to contain_exactly(:general, :back, :hints)
      expect(output[:general]).to contain_exactly(DocAuth::Errors::SHARP_LOW_ONE_SIDE)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::SHARP_LOW_FIELD)
      expect(output[:hints]).to eq(false)
    end
  end

  context 'The correct errors are delivered for selfie with metric error' do
    let(:metrics) do
      {
        front: {
          'HorizontalResolution' => 300,
          'VerticalResolution' => 300,
          'SharpnessMetric' => 25,
          'GlareMetric' => 25,
        },
        back: {
          'HorizontalResolution' => 300,
          'VerticalResolution' => 300,
          'SharpnessMetric' => 25,
          'GlareMetric' => 25,
        },
      }
    end

    context 'when liveness is enabled' do
      let(:liveness_enabled) { true }

      context 'when liveness check passed' do
        let(:face_match_result) { 'Pass' }
        it 'returns a metric error with no other error' do
          error_info = build_error_info(doc_result: 'Passed', image_metrics: metrics)
          errors = described_class.new(config).generate_doc_auth_errors(error_info)
          expect(errors.keys).to contain_exactly(:front, :back, :general, :hints)
        end
      end

      context 'when liveness check failed' do
        let(:face_match_result) { 'Fail' }
        it 'returns a metric error without a selfie error' do
          error_info = build_error_info(doc_result: 'Passed', image_metrics: metrics)
          errors = described_class.new(config).generate_doc_auth_errors(error_info)
          expect(errors.keys).to contain_exactly(:front, :back, :general, :hints)
        end
      end
    end
  end

  context 'with both doc type error and image metric error' do
    let(:metrics) do
      {
        front: {
          'HorizontalResolution' => 300,
          'VerticalResolution' => 300,
          'SharpnessMetric' => 50,
          'GlareMetric' => 50,
        },
        back: {
          'HorizontalResolution' => 300,
          'VerticalResolution' => 300,
          'SharpnessMetric' => 50,
          'GlareMetric' => 50,
        },
      }
    end
    it 'generate doc type error' do
      metrics[:front]['HorizontalResolution'] = 50
      error_info = build_error_info(
        doc_result: 'Failed',
        failed: [{ name: '2D Barcode Read', result: 'Attention' }],
        classification_info: { Back: vhic_classification_details,
                               Front: vhic_classification_details },
        image_metrics: metrics,
      )

      output = described_class.new(config).generate_doc_auth_errors(error_info)
      expect(output.keys).to contain_exactly(:general, :front, :back, :hints)

      expect(output[:general]).to contain_exactly(DocAuth::Errors::DOC_TYPE_CHECK)
      expect(output[:back]).to contain_exactly(DocAuth::Errors::CARD_TYPE)
      expect(output[:front]).to contain_exactly(DocAuth::Errors::CARD_TYPE)
      expect(output[:hints]).to eq(true)
    end
  end
end
