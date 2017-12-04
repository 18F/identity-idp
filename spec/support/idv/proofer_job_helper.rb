module ProoferJobHelper
  def mock_proofer_job_agent(config:, vendor:)
    allow(Figaro.env).to receive(config).and_return(vendor)

    agent = Idv::Agent.new(applicant: Proofer::Applicant.new({}), vendor: :mock)
    allow(Idv::Agent).to receive(:new).and_return(agent)
  end
end
