require 'chef'
require 'highline'
require 'chef/lxc'
require 'chef/application'
require 'chef/client'
require 'chef/config'
require 'chef/log'
require 'fileutils'
require 'tempfile'
require 'chef/providers'
require 'chef/resources'

class Chef::Application::LXC < Chef::Application

  banner "Usage: chef-lxc CONTAINER [RECIPE_FILE] [-e RECIPE_TEXT] [-s]"

  option :execute,
    :short        => "-e RECIPE_TEXT",
    :long         => "--execute RECIPE_TEXT",
    :description  => "Execute resources supplied in a string",
    :proc         => nil

  option :stdin,
    :short        => "-s",
    :long         => "--stdin",
    :description  => "Execute resources read from STDIN",
    :boolean      => true

  option :log_level,
    :short        => "-l LEVEL",
    :long         => "--log_level LEVEL",
    :description  => "Set the log level (debug, info, warn, error, fatal)",
    :proc         => lambda { |l| l.to_sym }

  option :help,
    :short        => "-h",
    :long         => "--help",
    :description  => "Show this message",
    :on           => :tail,
    :boolean      => true,
    :show_options => true,
    :exit         => 0

  option :version,
    :short        => "-v",
    :long         => "--version",
    :description  => "Show chef-lxc version",
    :boolean      => true,
    :proc         => lambda {|v| puts "Chef::LXC: #{::Chef::LXC::VERSION}"},
    :exit         => 0

  option :why_run,
    :short        => '-W',
    :long         => '--why-run',
    :description  => 'Enable whyrun mode',
    :boolean      => true

  option :color,
    :long         => '--[no-]color',
    :boolean      => true,
    :default      => true,
    :description  => "Use colored output, defaults to enabled"

  def initialize
    super
  end

  def reconfigure
    parse_options
    Chef::Config.merge!(config)
    configure_logging
  end

  def run_chef_recipe
    if config[:execute]
      recipe_text = config[:execute]
    elsif config[:stdin]
      recipe_text = STDIN.read
    else
      recipe_text = ::File.read(ARGV[1])
    end
    Chef::Config[:solo] = true
    ct = ::LXC::Container.new(ARGV.first)
    client = Chef::Client.new
    client.ohai.load_plugins
    ct.execute do
      client.run_ohai
      client.load_node
      client.build_node
      run_context = Chef::RunContext.new(client.node, {}, client.events)
      recipe = Chef::Recipe.new("(chef-lxc cookbook)", "(chef-lxc recipe)", run_context)
      recipe.instance_eval(recipe_text, '/foo/bar.rb', 1)
      runner = Chef::Runner.new(run_context)
      runner.converge
    end
  end

  def run_application
    begin
      parse_options
      run_chef_recipe
      Chef::Application.exit! "Exiting", 0
    rescue SystemExit => e
      raise
    rescue Exception => e
      Chef::Application.debug_stacktrace(e)
      Chef::Application.fatal!("#{e.class}: #{e.message}", 1)
    end
  end

  def run
    reconfigure
    run_application
  end
end
