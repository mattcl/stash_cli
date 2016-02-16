module StashCLI
  module GitUtils
    def self.current_branch
      `git rev-parse --abbrev-ref HEAD`.strip
    end
  end
end
