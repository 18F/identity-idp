class AppArtifactDownloader
  ARTIFACTS_TO_DOWNLOAD = [
    'saml2019.crt',
    'saml2019.key.enc',
    'saml2020.crt',
    'saml2020.key.enc',
    'saml2021.crt',
    'saml2021.key.enc',
  ].freeze

  attr_reader :artifacts, :destination, :local_artifacts_source

  def initialize(
    artifacts: ARTIFACTS_TO_DOWNLOAD,
    destination: 'tmp/artifacts',
    local_artifacts_source: 'artifacts'
  )
    @artifacts = artifacts
    @destination = destination
    @local_artifacts_source = local_artifacts_source
  end

  def download
    create_artifacts_folder
    if Identity::Hostdata.in_datacenter?
      download_all_from_s3
    else
      copy_all_from_filesystem
    end
  end

  private

  def copy_all_from_filesystem
    artifacts.each do |name|
      artifact_source = Rails.root.join(local_artifacts_source, name)
      artifact_destination = Rails.root.join(destination, name)
      FileUtils.copy(artifact_source, artifact_destination)
    end
  end

  def download_all_from_s3
    artifacts.each { |name| download_artifact_from_s3(name) }
  end

  def download_artifact_from_s3(name)
    bucket_name = "login-gov.secrets.#{aws_account_id}-#{AppConfig.env.aws_region}"
    s3_key = "#{Identity::Hostdata.env}/#{name}"
    destination_filepath = Rails.root.join(destination, name)
    s3_client.get_object(
      response_target: destination_filepath,
      bucket: bucket_name,
      key: s3_key,
    )
  end

  def create_artifacts_folder
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
