require 'rails_helper'

RSpec.describe InheritedProofingJob, type: :job do
  include_context 'va_api_context'
  include_context 'va_user_context'

  let(:document_capture_session) { DocumentCaptureSession.new(result_id: SecureRandom.hex) }
  let(:flow_session) { {} }
  let(:sp_session) { {} }
  let(:session) { { 'idv/inherited_proofing' => {}, sp: sp_session } }

  let(:controller) do
    instance_double(
      Idv:InheritedProofingController,
      session: session,
    )
  end

  describe '#perform' do
    it "does something" do
      InheritedProofingJob.new.perform(flow_session, document_capture_session)
    end
  end

#   => {"pii_from_user"=>{"uuid"=>"dbaa5434-ae75-4207-852c-3d4fb045fc06"},
# 10:57:44 web.1         |  "error_message"=>nil,
# 10:57:44 web.1         |  "Idv::Steps::InheritedProofing::GetStartedStep"=>true}


  #   let(:controller) do
  #   instance_double(
  #     Idv::DocAuthController,
  #     url_options: {},
  #     session: session,
  #     analytics: analytics,
  #     params: ActionController::Parameters.new(
  #       document_capture_session_uuid: document_capture_session_uuid,
  #     ),
  #   )
  # end
  # let(:session) { { 'idv/doc_auth' => {}, sp: sp_session } }
    # let(:flow) { Idv::Flows::DocAuthFlow.new(controller, session, 'idv/doc_auth') }
  # let(:sp_name) { nil }
  # let(:locale) { nil }

  # before do
  #   @decorated_session = instance_double(ServiceProviderSessionDecorator)
  #   allow(@decorated_session).to receive(:sp_name).and_return(sp_name)
    # allow(view).to receive(:decorated_session).and_return(@decorated_session)
    # allow(view).to receive(:flow_session).and_return(flow_session)
    # allow(view).to receive(:url_for).and_return('https://www.example.com/')
  # end
end