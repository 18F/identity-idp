module Idv
  module Steps
    module InheritedProofing
      # TODO: Include this
      include InheritedProofingConcern

      class AgreementStep < InheritedProofingBaseStep
        STEP_INDICATOR_STEP = :getting_started

        # TODO: All this.
        # This method is called from BaseStep#base_call ONLY if #form_submit is successful.
        # If #form_submit is successful, BaseStep#base_call takes the FormResponse returned here,
        # and merges the FormResponses returned from this method, with the FormResponse returned
        # from the call to #form_submit when BaseStep#base_call calls BaseStep#create_response.
        def call
          Rails.logger.debug('xyzzy: in AgreementStep')

          payload_hash = inherited_proofing_service!.execute
          form = inherited_proofing_form payload_hash
          form_response = form.submit

          if form_response.success?
            # rubocop:disable Layout/LineLength
            # TODO: WE NEED TO CONFIRM the hash key/values being put in session here that are necessary for the "hand off"!
            # TODO: WE NEED TO CONFIRM the hash key/values being put in session here that are necessary for the "hand off"!
            # TODO: WE NEED TO CONFIRM the hash key/values being put in session here that are necessary for the "hand off"!
            # TODO: WE NEED TO CONFIRM the hash key/values being put in session here that are necessary for the "hand off"!
            # rubocop:enable Layout/LineLength

            # Lexis Nexis Phone Finder expects dob (as opposed to birth_date).
            payload_hash[:dob] = payload_hash.delete(:birth_date)
            # Lexis Nexis Phone Finder does use/not need this.
            payload_hash.delete(:address)
            payload_hash.delete(:mhv_data)
            # NOTE: #flow_session delegated in BaseStep
            flow_session[:pii_from_user] = flow_session[:pii_from_user].to_h.merge(payload_hash)
          end

          # NOTE: BaseStep#base_call/#create_response appears to handle error scenarios, so
          # just return our FormResponse returned from the VA API call whether success or failure.
          form_response
        end

        def form_submit
          Idv::ConsentForm.new.submit(consent_form_params)
        end

        def consent_form_params
          params.require(:inherited_proofing).permit(:ial2_consent_given)
        end

        private

        # TODO: The below logic should be in the InheritedProofingConcern or
        # in an inherited proofing service factory.
        def inherited_proofing_service!
          inherited_proofing_service || raise('Inherited proofing service cannot be identified')
        end

        # rubocop:disable Layout/LineLength
        def inherited_proofing_service
          @inherited_proofing_service ||= if va_inherited_proofing?
                                            case IdentityConfig.store.inherited_proofing_enabled
                                            when true
                                              Idv::InheritedProofing::Va::Service.new va_inherited_proofing_auth_code
                                            else
                                              Idv::InheritedProofing::Va::Mocks::Service.new va_inherited_proofing_auth_code
                                            end
          end
        end

        def inherited_proofing_form(payload_hash)
          @inherited_proofing_form ||= if va_inherited_proofing?
                                         Idv::InheritedProofing::Va::Form.new payload_hash: payload_hash
          end
        end
        # rubocop:enable Layout/LineLength
      end
    end
  end
end
