module FlowPolicyHelper
  def stub_up_to(key, idv_session:, applicant: Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE)
    keys = keys_up_to(key: key)

    keys.each do |key|
      stub_step(key: key, idv_session: idv_session, applicant: applicant)
    end
  end

  def stub_step(key:, idv_session:, applicant: Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE)
    case key
    when :welcome
      idv_session.welcome_visited = true
    when :agreement
      idv_session.idv_consent_given = true
    when :hybrid_handoff
      idv_session.flow_path = 'standard'
    when :link_sent
      idv_session.flow_path = 'hybrid'
      idv_session.pii_from_doc = applicant.dup
    when :document_capture
      idv_session.pii_from_doc = applicant.dup
    when :ssn
      idv_session.ssn = applicant[:ssn]
    when :ipp_ssn
      idv_session.send(:user_session)['idv/in_person'] = {
        pii_from_user: applicant.dup,
      }
      idv_session.ssn = applicant[:ssn]
    when :verify_info
      idv_session.mark_verify_info_step_complete!
      idv_session.applicant = applicant.dup
    when :ipp_verify_info
      idv_session.mark_verify_info_step_complete!
      idv_session.applicant = applicant.dup
    when :phone
      idv_session.mark_phone_step_started!
    when :otp_verification
      idv_session.mark_phone_step_complete!
    when :request_letter
      idv_session.address_verification_mechanism = 'gpo'
      idv_session.vendor_phone_confirmation = false
      idv_session.user_phone_confirmation = false
    when :enter_password
      # FINAL!
    end
  end

  def keys_up_to(key:)
    case key
    when :welcome
      %i[welcome]
    when :agreement
      %i[welcome agreement]
    when :hybrid_handoff
      %i[welcome agreement hybrid_handoff]
    when :link_sent
      %i[welcome agreement hybrid_handoff link_sent]
    when :document_capture
      %i[welcome agreement hybrid_handoff document_capture]
    when :ssn
      %i[welcome agreement hybrid_handoff document_capture ssn]
    when :ipp_ssn
      %i[welcome agreement hybrid_handoff ipp_ssn]
    when :verify_info
      %i[welcome agreement hybrid_handoff document_capture ssn verify_info]
    when :ipp_verify_info
      %i[welcome agreement hybrid_handoff ipp_ssn ipp_verify_info]
    when :phone
      %i[welcome agreement hybrid_handoff document_capture ssn verify_info phone]
    when :otp_verification
      %i[welcome agreement hybrid_handoff document_capture ssn verify_info phone otp_verification]
    when :request_letter
      %i[welcome agreement hybrid_handoff document_capture ssn verify_info request_letter]
    when :enter_password
      %i[welcome agreement hybrid_handoff document_capture ssn verify_info phone otp_verification
         enter_password]
    else
      []
    end
  end
end
