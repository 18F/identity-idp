# frozen_string_literal: true

module Test
  class MockSocureDocumentCaptureController < ApplicationController
    before_action :check_not_in_prod

    def show
      if verify?
        simulate_socure_docv
        return
      end

      @url = test_mock_socure_url(verify: 1, hybrid: hybrid? ? 1 : 0)
    end

    private

    def check_not_in_prod
      render_not_found if Rails.env.production?
    end

    def build_fake_docv_result_response
      DocAuth::Socure::Responses::DocvResultResponse.new(
        http_response: Struct.new(:body, keyword_init: true).new(
          body: JSON.generate(
            {
              referenceId: SecureRandom.uuid,
              documentVerification: {
                customerProfile: {
                  customerUserId: '',
                  userId: SecureRandom.uuid,
                },
                decision: {
                  name: '',
                  value: 'accept',
                },
                documentData: {
                  dob: '1938-01-01',
                  documentNumber: 'ABCD-1234',
                  expirationDate: (Time.zone.now + 1.year).to_date,
                  firstName: 'Joey',
                  issueDate: 3.years.ago.to_date,
                  middleName: 'Joe-Joe',
                  surName: 'Junior Shabbadoo',
                  parsedAddress: {
                    physicalAddress: '1234 Fake St.',
                    physicalAddress2: 'Unit 99',
                    city: 'Fakeville',
                    state: 'CA',
                    zip: '90210',
                  },
                },
                documentType: {
                  state: 'WA',
                  country: 'US',
                },
                reasonCodes: [],
              },

            },
          ),
        ),
      )
    end

    def document_capture_session
      DocumentCaptureSession.find_by(
        uuid: if idv_session.present?
                idv_session.document_capture_session_uuid
              else
                session[:document_capture_session_uuid]
              end,
      )
    end

    def hybrid?
      params[:hybrid].to_i == 1
    end

    def idv_session
      return nil if user_session.nil?

      @idv_session ||= Idv::Session.new(
        user_session: user_session,
        current_user: current_user,
        service_provider: current_sp,
      )
    end

    def simulate_socure_docv
      # Fake what the Socure webhook processor would've done.
      # TODO: It'd be cool to just call the webhook processing code here

      document_capture_session.store_result_from_response(
        build_fake_docv_result_response,
      )

      if hybrid?
        redirect_to idv_hybrid_mobile_capture_complete_url
      else
        redirect_to idv_socure_document_capture_update_url
      end
    end

    def verify?
      params[:verify].to_i == 1
    end
  end
end
