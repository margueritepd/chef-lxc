require 'mixlib/shellout'
require 'chef/lxc_helper'

class Chef
  module LXC
    module ContainerHelper
      include Chef::LXCHelper

      def recipe(path = nil, &block)
        recipe_content = path ? File.read(path) : nil
        recipe_in_container(self, recipe_content, &block)
      end

      def command(cmd, opts = {})
        live_stream = opts[:live_stream] || $stdout
        out = execute(wait: true) do
          cmd = Mixlib::ShellOut.new(cmd)
          cmd.live_stream = live_stream
          cmd.run_command
          cmd.exitstatus
        end
        out
      end

      def command!(cmd, opts = {})
        exitstatus = command(cmd, opts)
        raise "Failed to execute: '#{cmd}'.\nExit code: #{exitstatus}" unless exitstatus.zero?
        exitstatus
      end
    end
  end
end
