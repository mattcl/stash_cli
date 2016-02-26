module StashCLI
  module GitUtils
    def self.current_branch
      `git rev-parse --abbrev-ref HEAD`.strip
    end

    def self.commits_from_branch(source_branch)
      current_branch = GitUtils.current_branch
      `git log --oneline #{source_branch}..#{current_branch} | cat`.strip
    end
  end
end
