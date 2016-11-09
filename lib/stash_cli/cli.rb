require 'thor'
require 'yaml'
require 'configatron'
require 'base64'

require 'stash_cli/client'
require 'stash_cli/git_utils'
require 'stash_cli/project'

module StashCLI
  class CLI < Thor
    include Thor::Actions

    attr_reader :project

    def self.source_root
      File.dirname(__FILE__)
    end

    def initialize(*args)
      super
    end

    class_option :config,
      aliases: '-c',
      type: :string,
      default: File.join(ENV['HOME'], '.stash_cli.yml'),
      desc: 'path to config file'

    desc 'init', 'generate a config file'
    def init
      @server = ask_required('stash server url:')
      @username = ask_required('stash username:')
      @password = ask_required('password:', echo: false)
      @project = ask_required("\nproject key:")
      @source = ask_required('source repo slug:')

      @target = ask('target repo slug [main]:')
      @target = 'main' if @target.empty?

      @target_branch = ask('target branch [master]:')
      @target_branch = 'master' if @target_branch.empty?

      @auth_token = Base64.encode64("#{@username}:#{@password}")

      dest = File.join(ENV['HOME'], '.stash_cli.yml')

      template('templates/stash_cli.yml.erb', dest)

      say "verify configuration in #{dest}"
    end

    desc 'commits SRC_BRANCH', 'list commits since source branch'
    def commits(src_branch)
      say GitUtils.commits_from_branch(src_branch)
    end

    desc 'users', 'list users'
    def users
      configure
      client = Client.new(configatron.server, configatron.auth_token)
      users = client.users.map { |data| [data['displayName'], data['name']] }
      users.unshift ['display name', 'slug']
      print_table(users)
    end

    desc 'branches', 'list branches in source'
    def branches
      configure
      client = Client.new(configatron.server, configatron.auth_token)
      resp = client.branches(project.project, project.source_slug)
      resp['values'].each do |value|
        say value['displayId']
      end
    end

    desc 'groups', 'list defined reviewer groups'
    def groups
      configure

      groups = [['empty:', '(this special group has no users)']]
      configatron.reviewer_groups.each do |name, users|
        groups << ["#{name}:", users.join(', ')]
      end

      say 'reviewer groups:'
      print_table(groups)
    end

    desc 'pr TITLE [OPTIONS]', 'open a pull request'
    option :interactive,
      aliases: '-i',
      type: :boolean,
      default: false,
      desc: 'run in interactive mode instead of just using defaults'

    option :description,
      aliases: '-d',
      type: :string,
      desc: 'the description'

    option :long_description,
      aliases: '-D',
      type: :boolean,
      desc: 'Write description in $EDITOR'

    option :open,
      type: :boolean,
      default: true,
      desc: 'open the pull request in a browser'

    option :groups,
      aliases: '-g',
      type: :array,
      default: [],
      desc: 'the groups (union) of reviewers for this pull request. There is a special group "empty" which means no reviewers'

    option :additional_reviewers,
      aliases: '-a',
      type: :array,
      default: [],
      desc: 'additional users to include in this pull request (will append to groups)'

    option :reviewers,
      aliases: '-r',
      type: :array,
      default: [],
      desc: 'the only users to include in this pull request (will ignore --groups and --additional-reviewers)'

    option :branch,
      aliases: '-b',
      type: :string,
      desc: 'the target branch for the pull request. Will default to the one in your config'

    option :dry_run,
      type: :boolean,
      default: false,
      desc: 'do not actually create the request'

    def pr(title)
      configure

      if options[:interactive]
        opts = interactive_pr(title)
      else
        opts = default_pr(title)
      end

      if options[:dry_run]
        say "dry run options: #{opts}"
        exit
      end

      client = Client.new(configatron.server, configatron.auth_token)
      pull_request = client.pull_request(opts)

      say 'pull request created'
      say "id: #{pull_request.id}"
      say "url: #{pull_request.url}"

      if options[:open]
        say 'opening in browser...'
        cmd = "#{configatron.browser_command} #{pull_request.url}"
        system(cmd)
      end
    end

    protected

    def get_description(target_branch)
      default_description = GitUtils.commits_from_branch(target_branch)

      if options[:long_description]
        if ENV['EDITOR'].nil? or ENV['EDITOR'].empty?
          say 'using --long-description but $EDITOR not set. Aborting.'
          exit 1
        end

        if options[:interactive]
          say 'getting description via $EDITOR'
        end

        tmpfile = File.join('/tmp', "pull_request_desc_#{Time.now.to_i}")
        File.open(tmpfile, 'w') { |f| f.puts default_description }

        system(ENV['EDITOR'], tmpfile)

        if File.exists?(tmpfile)
          contents = File.read(tmpfile)
          File.delete(tmpfile)
          return contents
        else
          say 'Aborting due to missing description'
          exit 1
        end
      elsif options[:interactive]
        description = ask("description [#{options[:description]}]:").strip
        return description unless description.empty?
      end

      return options[:description] if options[:description]

      return default_description
    end

    def initial_reviewers
      users = options[:reviewers]

      # we stop here if there are users specified
      return users if users.any?

      groups = options[:groups]
      if groups.any?
        if groups.include?('empty')
          reviewers = []
        else
          reviewers = groups.map do |group|
            if configatron.reviewer_groups.has_key?(group)
              configatron.reviewer_groups[group]
            else
              say "unknown group: #{group}"
              nil
            end
          end
        end

        reviewers = reviewers.compact.flatten.uniq
      else
        reviewers = configatron.reviewer_groups.default
      end

      additional_reviewers = options[:additional_reviewers]

      reviewers += additional_reviewers if additional_reviewers.any?

      say "computed reviewers: [#{reviewers.join(', ')}]"
      reviewers
    end

    def default_pr(title)
      reviewers = initial_reviewers

      target_branch = project.target_branch
      target_branch = options[:branch] if options[:branch]

      opts = {
        title: title,
        project: project.project,
        from_branch: GitUtils.current_branch,
        from_slug: project.source_slug,
        target_branch: target_branch,
        target_slug: project.target_slug,
        reviewers: reviewers
      }

      description = get_description(opts[:target_branch])

      opts[:description] = description if description

      opts
    end

    def interactive_pr(title)

      target_branch =
        ask("target branch [#{project.target_branch}]:").strip

      description = get_description(target_branch)

      target_branch = project.target_branch if target_branch.empty?

      reviewers = initial_reviewers

      if yes?("use custom reviewers? [y/yes/n/no empty is no]:")
        reviewers =
          ask("reviewers [comma-separated, empty for none]:").strip

        if reviewers.empty?
          reviewers = []
        else
          reviewers = reviewers.split(',').map(&:strip).compact
        end
      end

      opts = {
        title: title,
        project: project.project,
        from_branch: GitUtils.current_branch,
        from_slug: project.source_slug,
        target_branch: target_branch,
        target_slug: project.target_slug,
        reviewers: reviewers
      }

      opts[:description] = description if description

      opts
    end

    def configure
      if File.exist?(options[:config])
        conf = YAML.load_file(options[:config])
        configatron.configure_from_hash(conf)
      else
        say '!! no configuration file !!'
        say 'generate a basic config with "stash init"'
        exit 1
      end

      repo_dir = GitUtils.repo_dir
      proj_file = File.join(repo_dir, '.stash-proj')

      if File.exist?(proj_file)
        say 'using project from .stash-proj file'
        project_name = File.read('.stash-proj').strip

        # If you're declaring the project it had better exist
        unless configatron.projects.has_key?(project_name)
          say "!! project: #{project_name} requested but not defined !!"
          say 'add this project to your .stash_cli.yml or remove the .stash-proj file'
          exit 1
        end
      else
        project_name = File.basename(repo_dir)
      end

      if configatron.projects.has_key?(project_name)
        say "using defined project: #{project_name}"
        @project = Project.new(
          configatron.projects[project_name].project,
          configatron.projects[project_name].source_slug,
          configatron.projects[project_name].target_slug,
          configatron.projects[project_name].target_branch)

      else
        @project = Project.new(
          configatron.defaults.project,
          configatron.defaults.source_slug,
          configatron.defaults.target_slug,
          configatron.defaults.target_branch)
      end
    end

    def ask_required(statement, *args)
      val = ask(statement, *args)

      if val.empty?
        say 'input is required'
        return ask_required(statement, *args)
      end

      val
    end
  end
end
