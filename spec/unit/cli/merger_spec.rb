require "spec_helper"
require "securerandom"

describe Skylight::CLI::Merger do
  def run_shell(token: "token", success: true)
    status =
      begin
        shell = SpecHelpers::TestShell.new(yield) { |line, expected| expect(line).to match(expected) }

        described_class.new([token], {}, shell: shell).invoke_all

        0
      rescue SystemExit => e
        e.status
      end

    expect(status).to eq(success ? 0 : 1)
  end

  def generate_component(attrs = {})
    { "name" => "web", "environment" => "production", "guid" => SecureRandom.hex(4) }.merge(attrs)
  end

  before do
    allow_any_instance_of(Skylight::Api).to receive(:fetch_mergeable_apps) do
      double("response", body: mergeable_apps)
    end
  end

  let(:matchers) do
    {
      intro: /Hello! Welcome to the `skylight merge` CLI!/,
      explanation: /This CLI is for/,
      fetch: /Fetching your apps/,
      further_questions: /If you have any questions, please contact/,
      app_not_found: /Sorry, `skylight merge` is only able to merge apps that you own/,
      unlisted_app: /\d\. My app isn't listed here/
    }.freeze
  end

  let(:app1) { { guid: "abcdef123", name: "app1", components: [generate_component] } }

  context "not enough apps" do
    let(:mergeable_apps) { [app1] }

    specify do
      run_shell(success: false) do
        [
          matchers[:intro],
          matchers[:explanation],
          matchers[:fetch],
          /It does not appear that you are the owner of enough apps/,
          matchers[:further_questions]
        ]
      end
    end
  end

  context "has apps" do
    let(:app2) { { guid: "abcedf124", name: "app2", components: [generate_component] } }
    let(:app3) do
      { guid: "abcedf124", name: "app3", components: [generate_component, generate_component(environment: "staging")] }
    end
    let(:mergeable_apps) { [app1, app2, app3] }
    let(:app_list) { mergeable_apps.map.with_index { |a, i| /#{i + 1}\. #{a[:name]}/ }.push(matchers[:unlisted_app]) }
    let(:preamble_sequence) do
      [matchers[:intro], matchers[:explanation], matchers[:fetch], /Please specify the "parent" app/, *app_list]
    end
    # rubocop:disable Style/RegexpLiteral
    let(:success_sequence) do
      [
        /Merging.../,
        /Success!/,
        %r{=========================},
        %r{If you use a config/skylight.yml},
        /Remove any environment-specific `authentication` configs/,
        /If you're running in Rails and your Rails environment exactly matches `#{child_env}`/,
        %r{=========================},
        /If you configure Skylight using environment variables/,
        /Deploy the latest agent before updating your environment variables/,
        /Set `SKYLIGHT_AUTHENTICATION`/,
        /If you're running in Rails and your Rails environment exactly matches `#{child_env}`/,
        %r{=========================}
      ]
    end
    # rubocop:enable Style/RegexpLiteral

    before do
      allow_any_instance_of(Skylight::Api).to receive(:merge_apps!).with(
        "token",
        app_guid: app1[:guid],
        component_guid: app2[:components][0]["guid"],
        environment: child_env
      ) { merge_response }
    end

    let(:merge_response) { double("merge_response", status: 204) }
    let(:child_env) { "staging" }

    let(:choose_app1_child_sequence) do
      [
        /Ok! The parent app is: app1/,
        /Please specify the child app to be merged/,
        /1. app2/,
        /2. app3/,
        /3. app3.*\(staging\)/,
        matchers[:unlisted_app]
      ]
    end
    let(:choose_child_environment_sequence) do
      [
        /What environment is the child app\?/,
        /1\. development/,
        /2\. staging/,
        /3\. \[choose a different environment not listed here\]/
      ]
    end
    let(:confirm_environment_sequence) do
      [
        /Ok! The child environment will be: #{child_env}/,
        /Ok! Now we're going to merge `app2` into `app1` as `#{child_env}`/
      ]
    end

    specify "expected app not listed" do
      run_shell(success: false) do
        [
          *preamble_sequence,
          [/Which number\?/, mergeable_apps.count + 1],
          matchers[:app_not_found],
          matchers[:further_questions]
        ]
      end
    end

    specify "bad app input" do
      run_shell(success: false) do
        [
          *preamble_sequence,
          [/Which number\?/, "banana"],
          /Hmm/,
          # asks for app again
          *app_list,
          [/Which number\?/, mergeable_apps.count + 1],
          matchers[:app_not_found],
          matchers[:further_questions]
        ]
      end
    end

    context "straightforward merge" do
      specify do
        run_shell(success: true) do
          [
            *preamble_sequence,
            [/Which number\?/, 1],
            *choose_app1_child_sequence,
            [/Which number\?/, 1],
            /Ok! The child app is: app2/,
            *choose_child_environment_sequence,
            [/Which number\?/, 2],
            *confirm_environment_sequence,
            [%r{Proceed\? \[Y/n\]}, "Y"],
            *success_sequence,
            matchers[:further_questions]
          ]
        end
      end
    end

    context "custom env specified" do
      let(:child_env) { "staging-32" }
      specify do
        run_shell(success: true) do
          [
            *preamble_sequence,
            [/Which number\?/, 1],
            *choose_app1_child_sequence,
            [/Which number\?/, 1],
            /Ok! The child app is: app2/,
            *choose_child_environment_sequence,
            [/Which number\?/, 3],
            [/Please enter your environment name/, child_env],
            *confirm_environment_sequence,
            [%r{Proceed\? \[Y/n\]}, "Y"],
            *success_sequence,
            matchers[:further_questions]
          ]
        end
      end
    end

    context "bad env specified" do
      let(:child_env) { "staging-32" }
      specify do
        run_shell(success: true) do
          [
            *preamble_sequence,
            [/Which number\?/, 1],
            *choose_app1_child_sequence,
            [/Which number\?/, 1],
            /Ok! The child app is: app2/,
            *choose_child_environment_sequence,
            [/Which number\?/, "squirrel"],
            /Eh\? Please enter 1, 2, or 3/,
            *choose_child_environment_sequence,
            [/Which number\?/, 3],
            [/Please enter your environment name/, "staging! 42"],
            /Environment can only contain letters, numbers, and hyphens/,
            [/Please enter your environment name/, "production"],
            /Sorry, `app1` already has a `production` component that conflicts with this merge request/,
            [/Please enter your environment name/, child_env],
            *confirm_environment_sequence,
            [%r{Proceed\? \[Y/n\]}, "Y"],
            *success_sequence,
            matchers[:further_questions]
          ]
        end
      end
    end

    context "confirmation strictness" do
      specify do
        run_shell(success: true) do
          [
            *preamble_sequence,
            [/Which number\?/, 1],
            *choose_app1_child_sequence,
            [/Which number\?/, 1],
            /Ok! The child app is: app2/,
            *choose_child_environment_sequence,
            [/Which number\?/, 2],
            *confirm_environment_sequence,
            [%r{Proceed\? \[Y/n\]}, "b"],
            /Please respond 'Y' to merge or 'n' to cancel/,
            [%r{Proceed\? \[Y/n\]}, "n"],
            /Ok, come back any time/,
            matchers[:further_questions]
          ]
        end
      end
    end

    context "conflict during merge" do
      let(:error_message) { "HTTP 409: merge would violate uniqueness constraint" }
      before do
        allow_any_instance_of(Skylight::Api).to receive(:merge_apps!) do
          raise Skylight::Api::Conflict, error_message
        end
      end

      specify do
        run_shell(success: false) do
          [
            *preamble_sequence,
            [/Which number\?/, 1],
            *choose_app1_child_sequence,
            [/Which number\?/, 1],
            /Ok! The child app is: app2/,
            *choose_child_environment_sequence,
            [/Which number\?/, 2],
            *confirm_environment_sequence,
            [%r{Proceed\? \[Y/n\]}, "Y"],
            /Merging.../,
            /Something went wrong/,
            /#{error_message}/,
            matchers[:further_questions]
          ]
        end
      end
    end

    context "invalid token" do
      before do
        allow_any_instance_of(Skylight::Api).to receive(:fetch_mergeable_apps) do
          raise Skylight::Api::Unauthorized, "HTTP 401: bad token"
        end
      end

      specify do
        run_shell(success: false) do
          [
            matchers[:intro],
            matchers[:explanation],
            matchers[:fetch],
            /Provided merge token is invalid/,
            matchers[:further_questions]
          ]
        end
      end
    end
  end
end
