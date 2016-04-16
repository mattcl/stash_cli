module StashCLI
  class Project
    attr_reader :project, :source_slug, :target_slug, :target_branch

    def initialize(project, source_slug, target_slug, target_branch)
      @project = project
      @source_slug = source_slug
      @target_slug = target_slug
      @target_branch = target_branch
    end
  end
end
