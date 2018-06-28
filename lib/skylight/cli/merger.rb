require 'ostruct'
require 'skylight/util/http'
require 'thor'
require 'highline'

module Skylight
  module CLI
    class Merger < Thor::Group
      include Helpers

      def self.banner
        "#{basename} skylight merge MERGE_TOKEN"
      end

      STRINGS = {
        get_token: 'get your merge token from `https://www.skylight.io/merging`',
        unlisted: "My app isn't listed here :("
      }

      argument :merge_token, type: :string, desc: STRINGS[:get_token]

      def fetch_apps
        say "Fetching your apps from skylight.io..."
        @apps = api.fetch_mergeable_apps(@merge_token).body

        if @apps.count < 2
          done!(
            message: "It does not appear that you are the owner of enough apps (there's nothing we can merge).",
            success: false
          )
        end
      rescue Skylight::Api::Unauthorized
        done!(
          success: false,
          message: "Provided merge token is invalid.\n" \
            "Please #{STRINGS[:get_token]}" \
            "and run `skylight merge <merge token>` again."
        )
      end

      def ask_for_parent_app
        @parents ||= begin
          a = (@apps + [{ name: STRINGS[:unlisted], components: [], unlisted: true }])
          a.each_with_object({}).with_index do |(app, h), i|
            h[i + 1] = OpenStruct.new(app)
          end
        end

        say "\nHello! Please specify your *parent* app.\n" \
          "In most cases, this will be the production app handling web requests.", :green

        @parent_app = ask_for_app(@parents)
      end

      def confirm_parent
        say "Ok, parent app is `#{set_color(@parent_app.name, :green)}`"
      end

      def ask_for_child_app
        say "\nPlease specify the child app to be merged into the parent app.", :green
        @child_app = ask_for_app(children, &method(:format_component))
      end

      def confirm_child
        say "Ok, child app is #{format_component(@child_app)}", :yellow
      end

      def ask_for_child_env
        say "\nWhat environment is the child app?\n" \
          "In many cases, this will be equivalent to the Rails " \
          "environment, i.e., `development`.", :green

        available_envs = %w(development staging) - @parent_app.components.map { |c| c['environment'] }

        say "1. development"
        say "2. staging"
        say "3. [choose a different environment not listed here]"

        i = ask("Which number?").chomp.to_i

        @child_env = case i
                     when 1 then 'development'
                     when 2 then 'staging'
                     when 3
                       specify_child_env
                     else
                       say("Eh? Please enter 1, 2, or 3.", :red)
                       ask_for_child_env
                     end
      end

      def confirm_child_env
        say "child env: #{set_color(@child_env, :yellow)}"
      end

      def confirm_everything
        say "\nOk, now we're going to merge `#{set_color(format_component(@child_app), :yellow)}` " \
          "into `#{set_color(@parent_app.name, :green)}` as `#{set_color(@child_env, :yellow)}`"
      end

      def do_confirm
        proceed = ask("Proceed? [Y/n]").chomp

        case proceed
        when 'Y'
          do_merge
        when 'n'
          done!(
            success: true,
            message: "Ok, come back any time."
          )
        else
          say("Please respond 'Y' to merge or 'n' to cancel.", :red)
          do_confirm
        end
      end

      def print_new_config_instructions
        say "Success!", :green
        say "=======================================================", :yellow
        say "If you're running in Rails, and your rails environment exactly matches `#@child_env`, we will " \
          "automatically detect and report that environment when your agent connects. Otherwise, you " \
          "should set `SKYLIGHT_ENV='#@child_env'` when running in this environment.\n", :yellow

        say "IMPORTANT!", :yellow
        say "If you use a config/skylight.yml file with different environment settings, " \
          "you should remove the additional `:authentication` configs from non-production environments. " \
          "All of your environments for this app will connect using your main authentication token.\n", :yellow

        say "IMPORTANT!", :yellow
        say "If you use a SKYLIGHT_AUTHENTICATION environment variable, you can now use your production token " \
          "for all environments belonging to this app.", :yellow

        say "=======================================================", :yellow
        done!
      end

      private

      def do_merge
        api.merge_apps!(@merge_token,
                        app_guid: @parent_app.guid,
                        component_guid: @child_app.guid,
                        environment: @child_env
                       )
      rescue => e
        say("Something went wrong. Please contact support@skylight.io for more information.", :red)
        done!(message: e.message, success: false)
      end

      def done!(message: nil, success: true)
        shell.padding = 0
        say "\n"

        if success
          say(message, :green) if message
          say "If you have any further questions, please contact support@skylight.io.", :green
          exit 0
        else
          say message || "Skylight wasn't able to merge your apps.", :red
          say "If you have any further questions, please contact support@skylight.io.", :yellow
          exit 1
        end
      end

      def ask_for_app(app_list, &formatter)
        formatter ||= :name.to_proc
        app_list.each do |index, app|
          say("\t#{index}. #{formatter.(app)}")
        end

        n = ask("Which number?").chomp.to_i

        if !app_list.key?(n)
          say "Hmm?"
          ask_for_app(app_list, &formatter)
        elsif app_list[n].unlisted
          done!(
            success: false,
            message: "Sorry, `skylight merge` is only able to merge apps that you own."
          )
        else
          app_list[n]
        end
      end

      def api
        @api ||= Skylight::Api.new(config)
      end

      def format_component(component)
        parts = [].tap do |ary|
          ary << component.name unless component.name == 'web'
          ary << component.environment unless component.environment == 'production'
        end

        str = ''
        str << component.app_name
        str << Thor::Shell::Color.new.set_color(" (#{parts.join(':')})", :yellow) if parts.any?
        str
      end

      def validate_mergeability(child_app, child_env)
        errors = []

        unless valid_component?(child_app.name, child_env)
          errors << "Environment can only contain letters, numbers, and hyphens."
        end

        if @parent_app && parent_component_fingerprints.include?([child_app.name, child_env])
          errors << "Sorry, `#{@parent_app.name}` already has a `#{child_env}` " \
            "component that conflicts with this merge request. Please choose a new environment."
        end

        return child_env unless errors.any?

        say errors.join("\n"), :red

        yield
      end

      def valid_component?(component_name, env)
        return false unless env
        Skylight::Util::Component.new(env, component_name) && true
      rescue ArgumentError
        false
      end

      def parent_component_fingerprints
        @parent_app.components.map { |x| x.values_at('name', 'environment') }
      end

      def children
        Enumerator.new do |yielder|
          @parents.each do |_, app|
            next if app == @parent_app
            app.components.each do |component|
              yielder << OpenStruct.new({ app_name: app.name }.merge(component))
            end
          end

          yielder << OpenStruct.new({ app_name: STRINGS[:unlisted], unlisted: true })
        end.each_with_object({}).with_index do |(c, r), i|
          r[i + 1] = c
        end.tap do |result|
          if result.values.all?(&:unlisted)
            done!(
              success: false,
              message: "Sorry, you do not have any apps that can be merged into `#{@parent_app.name}`"
            )
          end
        end
      end

      def specify_child_env
        validate_mergeability(
          @child_app,
          ask("Please enter your environment name (only lowercase letters, numbers, or hyphens): ", :green).chomp
        ) do
          specify_child_env
        end
      end
    end
  end
end
