VIEW_SCHEMA_VERSION = 2

class SequentMigrations < Sequent::Migrations::Projectors
  def self.version
    VIEW_SCHEMA_VERSION
  end

  def self.versions
    {
      '1' => [
        # List of migrations for version 1
      ],
      '2' => [
        # List of migrations for version 2
        ProfileProjector,
      ],
    }
  end
end
