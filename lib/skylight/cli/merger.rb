require "skylight/util/http"
require "thor"
require "highline"

module Skylight
  module CLI
    class Merger < Thor::Group
      include Helpers

      def self.banner
        "#{basename} skylight merge MERGE_TOKEN"
      end

      STRINGS = {
        get_token: "get your merge token from `https://www.skylight.io/merging`",
        unlisted: "My app isn't listed here :("
      }.freeze

      argument :merge_token, type: :string, desc: STRINGS[:get_token]

      def welcome
        say "\nHello! Welcome to the `skylight merge` CLI!\n", :green

        say "This CLI is for Skylight users who already have Skylight Environments set up\n" \
              "using the legacy method of creating a separate Skylight app per environment.\n" \
              "Use this CLI to merge legacy environment apps into their parent apps as Environments."
      end

      def fetch_apps
        say "\nFetching your apps from skylight.io..."
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
          message:
            "Provided merge token is invalid.\n" \
              "Please #{STRINGS[:get_token]}" \
              "and run `skylight merge <merge token>` again."
        )
      end

      def ask_for_parent_app
        @parents ||=
          begin
            a = (@apps + [{ name: STRINGS[:unlisted], components: [], unlisted: true }])
            a.each_with_object({}).with_index { |(app, h), i| h[i + 1] = wrap_hash(app) }
          end

        say "\nLet's begin!\n\n" \
              "Please specify the \"parent\" app.\n" \
              "In most cases, this will be the production app handling web requests.",
            :green

        @parent_app = ask_for_app(@parents)
      end

      def confirm_parent
        say "\nOk! The parent app is: #{@parent_app.name}", :green
      end

      def ask_for_child_app
        say "Please specify the child app to be merged into the parent app as an Environment.", :green
        @child_app = ask_for_app(children, &method(:format_component))
      end

      def confirm_child
        say "\nOk! The child app is: #{set_color(format_component(@child_app), :yellow)}", :green
      end

      def ask_for_child_env
        say "\nWhat environment is the child app?\n" \
              "In many cases, this will be equivalent to the Rails " \
              "environment, i.e., `development`.",
            :green

        say "1. development"
        say "2. staging"
        say "3. [choose a different environment not listed here]"

        i = ask("\nWhich number?").chomp.to_i

        @child_env =
          case i
          when 1
            "development"
          when 2
            "staging"
          when 3
            specify_child_env
          else
            say("\nEh? Please enter 1, 2, or 3.", :red)
            ask_for_child_env
          end
      end

      def confirm_child_env
        say "\nOk! The child environment will be: #{set_color(@child_env, :yellow)}"
      end

      def confirm_everything
        say "\nOk! Now we're going to merge `#{set_color(format_component(@child_app), :yellow)}` " \
              "into `#{set_color(@parent_app.name, :green)}` as `#{set_color(@child_env, :yellow)}`."
      end

      def do_confirm
        proceed = ask("Proceed? [Y/n]", :yellow).chomp

        case proceed.upcase
        when "Y", ""
          do_merge
        when "N"
          done!(success: true, message: "Ok, come back any time.")
        else
          say("Please respond 'Y' to merge or 'n' to cancel.", :red)
          do_confirm
        end
      end

      def print_new_config_instructions
        say "\nSuccess!\n", :green

        say "=======================================================\n", :yellow

        say "IMPORTANT!\n" \
              "If you use a config/skylight.yml file to configure Skylight:\n",
            :yellow

        say "The #{@child_env} environment for the #{@parent_app.name} app\n" \
              "will now connect using the default authentication token for the app.\n" \
              "Remove any environment-specific `authentication` configs from the\n" \
              "#{@parent_app.name} #{@child_env} environment.\n",
            :yellow

        say "If you're running in Rails and your Rails environment exactly matches `#{@child_env}`,\n" \
              "we will automatically detect and report that environment when your agent connects.\n" \
              "Otherwise, you should set `env: '#{@child_env}'` as environment-specific configuration for\n" \
              "#{@child_env}'s Rails environment. For example:\n" \
              "```yml\n" \
              "staging:\n" \
              "  env: staging-42\n" \
              "```\n",
            :yellow

        say "=======================================================\n", :yellow

        say "IMPORTANT!\n" \
              "If you configure Skylight using environment variables:\n",
            :yellow

        say "Deploy the latest agent before updating your environment variables.\n", :yellow

        say "The #{@child_env} environment for the #{@parent_app.name} app\n" \
              "will now connect using the default authentication token for the app.\n" \
              "Set `SKYLIGHT_AUTHENTICATION` in the #{@child_env} environment to the\n" \
              "#{@parent_app.name} app's authentication token.\n",
            :yellow

        say "If you're running in Rails and your Rails environment exactly matches `#{@child_env}`,\n" \
              "we will automatically detect and report that environment when your agent connects.\n" \
              "Otherwise, you should set `SKYLIGHT_ENV=#{@child_env}` when running in this environment.\n",
            :yellow

        say "=======================================================", :yellow

        done!
      end

      private

      def wrap_hash(hash)
        hash.each_with_object(ActiveSupport::OrderedOptions.new) do |(key, value), result|
          result[key] = value
        end
      end

      def do_merge
        say "Merging..."

        api.merge_apps!(
          @merge_token,
          app_guid: @parent_app.guid,
          component_guid: @child_app.guid,
          environment: @child_env
        )
      rescue StandardError => e
        say("Something went wrong. Please contact support@skylight.io for more information.", :red)
        done!(message: e.message, success: false)
      end

      def done!(message: nil, success: true)
        shell.padding = 0
        say "\n"

        if success
          say(message, :green) if message
          say "If you have any questions, please contact support@skylight.io.", :green
          exit 0
        else
          say message || "Skylight wasn't able to merge your apps.", :red
          say "If you have any questions, please contact support@skylight.io.", :yellow
          exit 1
        end
      end

      def ask_for_app(app_list, &formatter)
        formatter ||= :name.to_proc
        app_list.each { |index, app| say("\t#{index}. #{formatter.call(app)}") }

        n = ask("\nWhich number?").chomp.to_i

        if !app_list.key?(n)
          say "\nHmm?"
          ask_for_app(app_list, &formatter)
        elsif app_list[n].unlisted
          done!(success: false, message: "Sorry, `skylight merge` is only able to merge apps that you own.")
        else
          app_list[n]
        end
      end

      def api
        @api ||= Skylight::Api.new(config)
      end

      def format_component(component)
        parts =
          [].tap do |ary|
            ary << component.name unless component.name == "web"
            ary << component.environment unless component.environment == "production"
          end

        str = ""
        str << component.app_name
        str << Thor::Shell::Color.new.set_color(" (#{parts.join(":")})", :yellow) if parts.any?
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

        Util::Component.new(env, component_name) && true
      rescue ArgumentError
        false
      end

      def parent_component_fingerprints
        @parent_app.components.map { |x| x.values_at("name", "environment") }
      end

      def children
        ret =
          Enumerator.new do |yielder|
            @parents.each do |_, app|
              next if app == @parent_app

              app.components.each do |component|
                yielder << wrap_hash({ app_name: app.name }.merge(component)) 
              end
            end

            yielder << wrap_hash(app_name: STRINGS[:unlisted], unlisted: true)
          end

        ret = ret.each_with_object({}).with_index { |(c, r), i| r[i + 1] = c }

        ret.tap do |result|
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
        ) { specify_child_env }
      end
    end
  end
end
