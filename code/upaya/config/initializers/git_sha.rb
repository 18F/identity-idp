# Get the deployed git revision and version
# thanks to: http://houseofding.com/2013/11/display-git-revision-in-your-application/
module Git
  def self.store_git_attribute_constants
    %w(REVISION VERSION).each do |attribute|
      Git.const_set(attribute, git_attribute(attribute))
    end
  end

  def self.git_attribute(attribute)
    return 'Not a Git repo' unless Git.git_repo?

    if attribute == 'REVISION'
      `git rev-parse --short HEAD`.chomp
    elsif attribute == 'VERSION'
      `git describe --tags $(git rev-list --tags --max-count=1)`.chomp
    end
  end

  def self.git_repo?
    `git branch 2> /dev/null`.length > 0
  end
end

Git.store_git_attribute_constants
