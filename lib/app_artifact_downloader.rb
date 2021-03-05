class AppArtifactDownloader
  ARTIFACTS_TO_DOWNLOAD = [
    'saml2019.crt',
    'saml2019.key.enc',
    'saml2020.crt',
    'saml2020.key.enc',
    'saml2021.crt',
    'saml2021.key.enc',
  ].freeze

  attr_reader :artifacts, :destination

  def initialize(artifacts: ARTIFACTS_TO_DOWNLOAD, destination: 'tmp/artifacts')
    @artifacts = artifacts
    @destination = destination
  end

  def download
    return unless Identity::Hostdata.in_datacenter?

    create_artifacts_folder(destination)
    artifacts.each { |name| download_artifact(name, destination) }
  end

  private

  def download_artifact(name, destination)
    bucket_name = "login-gov.secrets.#{aws_account_id}-#{AppConfig.env.aws_region}"
    s3_key = "#{Identity::Hostdata.env}/#{name}"
    destination_filepath = Rails.root.join(destination, name)
    s3_client.get_object(
      response_target: destination_filepath,
      bucket: bucket_name,
      key: s3_key,
    )
  end

  def create_artifacts_folder(destination)
    FileUtils.mkdir_p(Rails.root.join(destination))
  end

  def aws_account_id
    @aws_account_id ||= sts_client.get_caller_identity.account
  end

  def sts_client
    Aws::STS::Client.new
  end

  def s3_client
    @s3_client ||= Aws::S3::Client.new(region: AppConfig.env.aws_region)
  end
end
