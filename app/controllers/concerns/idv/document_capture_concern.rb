module Idv
  module DocumentCaptureConcern
    extend ActiveSupport::Concern

    def save_proofing_components(user)
      return unless user

      doc_auth_vendor = DocAuthRouter.doc_auth_vendor(
        discriminator: document_capture_session_uuid,
        analytics: analytics,
      )

      component_attributes = {
        document_check: doc_auth_vendor,
        document_type: 'state_id',
      }
      ProofingComponent.create_or_find_by(user: user).update(component_attributes)
    end

    def successful_response
      FormResponse.new(success: true)
    end

    # copied from Flow::Failure module
    def failure(message, extra = nil)
      flow_session[:error_message] = message if defined?(flow_session)
      form_response_params = { success: false, errors: { message: message } }
      form_response_params[:extra] = extra unless extra.nil?
      FormResponse.new(**form_response_params)
    end

    # @param [DocAuth::Response,
    #   DocumentCaptureSessionAsyncResult,
    #   DocumentCaptureSessionResult] response
    def extract_pii_from_doc(user, response, store_in_session: false)
      pii_from_doc = response.pii_from_doc.merge(
        uuid: user.uuid,
        phone: user.phone_configurations.take&.phone,
        uuid_prefix: ServiceProvider.find_by(issuer: sp_session[:issuer])&.app_id,
      )

      puts '---------------------------------------------------------------------------------------'
      puts 'extract_pii_from_doc'
      puts "defined?(flow_session) = #{defined?(flow_session).inspect}"
      puts "flow_session = #{flow_session.inspect}"
      puts "store_in_session = #{store_in_session.inspect}"
      puts "response = #{response.inspect}"
      puts "pii_from_doc = #{pii_from_doc.inspect}"
      puts "flow_session[:pii_from_doc] = #{flow_session[:pii_from_doc].inspect}"
      puts "user_session = #{user_session.inspect}"
      puts Thread.current.backtrace.
        filter { |line| !line.include?('lib/ruby/gems') }.
        map { |line| line.sub(Rails.root.to_s, '') }.
        map { |line| "    #{line}" }.
        join("\n")

      if defined?(flow_session) # hybrid mobile does not have flow_session
        flow_session[:had_barcode_read_failure] = response.attention_with_barcode?
        if store_in_session
          flow_session[:pii_from_doc] ||= {}
          flow_session[:pii_from_doc].merge!(pii_from_doc)
          idv_session.clear_applicant!
        end
      elsif store_in_session
        raise 'flow_session is not available'
      end

      track_document_issuing_state(user, pii_from_doc[:state])

      puts 'after store --'
      puts "flow_session = #{flow_session.inspect}"
      puts "user_session = #{user_session.inspect}"
      puts '---------------------------------------------------------------------------------------'
    end

    def stored_result
      return @stored_result if defined?(@stored_result)
      @stored_result = document_capture_session&.load_result
    end

    private

    def track_document_issuing_state(user, state)
      return unless IdentityConfig.store.state_tracking_enabled && state
      doc_auth_log = DocAuthLog.find_by(user_id: user.id)
      return unless doc_auth_log
      doc_auth_log.state = state
      doc_auth_log.save!
    end
  end
end
