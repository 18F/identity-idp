module LexisNexisFixtures
  def self.true_id_response_success
    load_response_fixture('true_id_response_success.json')
  end

  def self.true_id_response_success_2
    load_response_fixture('true_id_response_success_2.json')
  end

  def self.true_id_response_failure
    load_response_fixture('true_id_response_failure_no_liveness.json')
  end

  def self.load_response_fixture(filename)
    path = File.join(
      File.dirname(__FILE__),
      '../fixtures/lexis_nexis_responses',
      filename,
    )
    File.read(path)
  end
end
