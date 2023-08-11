module Idv::Engine::Events
  extend Dsl

  # event :auth_user_changed_password do
  #   description 'The user has changed their password'
  # end

  # namespace :auth do
  #   event :user_changed_password do
  #     description 'The user has changed their password.'
  #     payload(
  #       password: :string,
  #     )
  #   end

  #   event :user_reset_password do
  #     description <<~END
  #       The user has reset their password and will not be able to access their IDV PII until providing
  #       their personal key.
  #     END
  #   end
  # end

  # namespace :idv do
  #   event :user_started do
  #     description <<~END
  #       The user has confirmed their desire to begin the identity verification process. They have
  #       NOT necessarily yet consented to share their PII with Login.gov.
  #     END
  #   end

  #   event :user_consented_to_share_pii do
  #     description <<~END
  #       The user has consented to share PII with Login.gov for the purposes of identity verification.
  #     END
  #   end

  #   event :documents_submitted_to_acuant do
  #     description <<~END
  #       The user has uploaded identity documents, and Login.gov has submitted them to Acuant for
  #       processing.
  #     END
  #     payload :doc_auth_result
  #   end

  #   event :documents_submitted_to_trueid do
  #     description <<~END
  #       The user has uploaded identity documents, and Login.gov has submitted them to LexisNexis
  #       TrueID for processing.
  #     END
  #     payload :doc_auth_result
  #   end

  #   event :user_entered_password do
  #     description <<~END
  #       The user has entered their password to encrypt their PII.
  #     END
  #     payload Idv::Engine::Payloads::Password
  #   end

  #   event :user_entered_ssn do
  #     description <<~END
  #       The user has entered their Social Security Number (SSN).
  #     END
  #     payload Idv::Engine::Payloads::Ssn
  #   end

  #   namespace :fraud do
  #     event :threatmetrix_check_initiated do
  #       description <<~END
  #         Login.gov has initiated an automated fraud check for the user using LexisNexis ThreatMetrix.
  #       END
  #       payload(
  #         threatmetrix_session_id: {
  #           type: :string,
  #           description: "A UUID reported to ThreatMetrix identifying the user's session.",
  #         },
  #       )
  #     end

  #     event :threatmetrix_check_completed do
  #       description <<~END
  #         Login.gov requested the result of an automated fraud check.
  #       END
  #       payload(
  #         request_success: {
  #           type: :boolean,
  #           description: 'Was the underlying HTTP request successfully made and completed?',
  #         },
  #         request_timed_out: {
  #           type: :boolean,
  #           description: 'Did the underlying HTTP request time out?',
  #         },
  #         response_status: {
  #           type: :number,
  #           description: <<~END,
  #             HTTP status code returned from ThreatMetrix. (For logging purposes only, not
  #             decisional -- use `request_success` to determine if the HTTP request succeeded,
  #             and `threatmetrix_review_status == 'pass'` to determine if the session passed
  #             automated fraud checks.
  #           END
  #         },
  #         threatmetrix_session_id: {
  #           type: :string,
  #           description: "A UUID reported to ThreatMetrix identifying the user's session.",
  #         },
  #         threatmetrix_review_status: {
  #           type: :string,
  #           enum: ['pass', 'reject', 'review'],
  #           description: 'Result of ThreatMetrix review',
  #         },
  #       )
  #     end
  #   end

  #   event :user_updated_mailing_address do
  #     description <<~END
  #       The user manually updated their mailing address.
  #     END
  #     payload(
  #       address: :address,
  #     )
  #   end

  #   event :user_verified_their_info do
  #     description <<~END
  #       The user confirmed the accuracy of the PII on file and chose to continue the IDV process.
  #     END
  #   end

  #   event :info_submitted_to_aamva do
  #     description <<~END
  #       The information from the user's identity documents was submitted to the American Association
  #       of Motor Vehicle Administrators (AAMVA) for verification.
  #     END
  #     payload
  #   end

  #   event :info_submitted_to_lexisnexis_trueid do
  #     description <<~END
  #       Login.gov made a request to LexisNexis TrueID to verify the user's identity.
  #     END
  #     payload
  #   end

  #   namespace :gpo do
  #     event :user_requested_letter do
  #       description 'The user has requested a letter to verify their address.'
  #       payload
  #     end

  #     event :user_verified_otp do
  #       description 'The user entered the one time password (OTP) they received via US mail.'
  #       payload
  #     end
  #   end

  #   event :residential_address_submitted_to_instantverify do
  #     description <<~END
  #       The user's residential address was submitted to LexisNexis InstantVerify.
  #       This is used during the In-Person Proofing flow and may be different than the address
  #       on their identification documents.
  #     END
  #     payload
  #   end

  #   event :address_submitted_to_instantverify do
  #     description <<~END
  #       The user's address was submitted to LexisNexis InstantVerify.
  #     END
  #     payload
  #   end
  # end
end
