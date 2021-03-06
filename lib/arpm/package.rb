module ARPM
  class Package

    attr_accessor :name
    attr_accessor :authors
    attr_accessor :versions
    attr_accessor :repository

    def initialize(opts = {})
      opts.each { |k,v| instance_variable_set("@#{k}", v) }
    end

    # Search for a new package
    def self.search(name, exact_match = true)

      # Grab the package list
      data = URI.parse("https://raw.githubusercontent.com/alfo/arpm/master/packages.json").read
      packages = JSON.parse(data)

      if exact_match

        # Search the packages for one with the same name
        remote_packages = packages.select { |p| p['name'] == name }

      else

        # Search for packages with similar names and return them
        remote_packages = packages.select { |p| p['name'].include? name }

      end

      # Did the search return any results?
      if remote_packages.any?

        packages = []
        remote_packages.each do |remote_package|

          # Get a list of tags from the remote repo
          tags = Git::Lib.new.ls_remote(remote_package["repository"])["tags"]

          # Delete any tags that aren't version numbers
          tags.each { |t| tags.delete(t) unless t[0].is_number? }

          # Sort the tags newest to oldest
          versions = Hash[tags.sort.reverse]

          # Create a new package object and return it
          packages << Package.new(:name => remote_package["name"],
                      :authors => remote_package["authors"],
                      :repository => remote_package["repository"],
                      :versions => versions)

        end

        if exact_match
          return packages.first
        else
          return packages
        end

      else
        # The package doesn't exist, so return false
        false
      end
    end

    def latest_version
      if versions.kind_of?(Array)
        versions.first
      else
        versions.keys.first.to_s
      end
    end

    def install_path(version = nil)

      # Take the latest_version unless it's been specified
      version = latest_version unless version

      # Creat the install path
      path = ARPM::Config.base_directory + name

      # Arduino doesn't like dots or dashes in library names
      path = path + "_#{version.gsub('.', '_')}"

    end

    def install(version)
      # Clone the repository!
      repo = Git.clone(repository, install_path(version))

      # It does, so checkout the right version
      repo.checkout("tags/#{version}")

      # Register the package to the list
      register(version)
    end

    def uninstall(version)
      # Remove the files
      FileUtils.rm_r(install_path(version)) rescue ""

      # Unregister it
      unregister(version)
    end

    def register(version)
      ARPM::List.register(self, version)
    end

    def unregister(version)
      ARPM::List.unregister(self, version)
    end

    def installed_versions
      ARPM::List.versions(self.name)
    end

  end
end
