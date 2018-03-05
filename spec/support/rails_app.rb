class ControllerError < StandardError; end

class CustomMiddleware

  def initialize(app)
    @app = app
  end

  def call(env)
    if env["PATH_INFO"] == "/middleware"
      return [200, { }, ["CustomMiddleware"]]
    end

    @app.call(env)
  end

end

class NonClosingMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    res = @app.call(env)

    # NOTE: We are intentionally throwing away the response without calling close
    # This is to emulate a non-conforming Middleware
    if env["PATH_INFO"] == "/non-closing"
      return [200, { }, ["NonClosing"]]
    end

    res
  end
end

class NonArrayMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    if env["PATH_INFO"] == "/non-array"
      return Rack::Response.new(["NonArray"])
    end

    @app.call(env)
  end
end

class InvalidMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    if env["PATH_INFO"] == "/invalid"
      return "Hello"
    end

    @app.call(env)
  end
end

class MyApp < Rails::Application
  config.secret_key_base = '095f674153982a9ce59914b561f4522a'

  config.active_support.deprecation = :stderr

  config.logger = Logger.new(STDOUT)
  config.logger.level = Logger::DEBUG

  config.eager_load = false

  # This class has no name
  config.middleware.use(Class.new do
    def initialize(app)
      @app = app
    end

    def call(env)
      if env["PATH_INFO"] == "/anonymous"
        return [200, { }, ["Anonymous"]]
      end

      @app.call(env)
    end
  end)

  config.middleware.use NonClosingMiddleware
  config.middleware.use NonArrayMiddleware
  config.middleware.use InvalidMiddleware
  config.middleware.use CustomMiddleware

  def self.boot
    MyApp.initialize!

    MyApp.routes.draw do
      resources :users do
        collection do
          get :failure
          get :handled_failure
          get :header
          get :status
          get :no_template
        end
      end
      get '/metal' => 'metal#show'
    end
  end
end

# We include instrument_method in multiple places to ensure
# that all of them work.

class ::UsersController < ActionController::Base
  include Skylight::Helpers

  if respond_to?(:before_action)
    before_action :authorized?
    before_action :set_variant
  else
    before_filter :authorized?
    before_filter :set_variant
  end

  rescue_from 'ControllerError' do |exception|
    render json: { error: exception.message }, status: 500
  end

  def index
    Skylight.instrument category: 'app.inside' do
      if Rails.version =~ /^4\./
        render text: "Hello"
      else
        render plain: "Hello"
      end
      Skylight.instrument category: 'app.zomg' do
        # nothing
      end
    end
  end
  instrument_method :index

  instrument_method
  def show
    respond_to do |format|
      format.json do |json|
        json.tablet { render json: { hola_tablet: params[:id] } }
        json.none   { render json: { hola: params[:id] } }
      end
      format.html do
        if Rails.version =~ /^4\./
          render text: "Hola: #{params[:id]}"
        else
          render plain: "Hola: #{params[:id]}"
        end
      end
    end
  end

  def failure
    raise "Fail!"
  end

  def handled_failure
    raise ControllerError, "Handled!"
  end

  def header
    Skylight.instrument category: 'app.zomg' do
      head 200
    end
  end

  def status
    s = params[:status] || 200
    if Rails.version =~ /^4\./
      render text: s, status: s
    else
      render plain: s, status: s
    end
  end

  def no_template
    # This action has no template to auto-render
  end

  private

    def authorized?
      true
    end

    # It's important for us to test a method ending in a special char
    instrument_method :authorized?, title: "Check authorization"

    def set_variant
      request.variant = :tablet if params[:tablet]
    end

end

class ::MetalController < ActionController::Metal
  include ActionController::Instrumentation

  def show
    render({
      status: 200,
      text: "Zomg!"
    })
  end

  def render(options={})
    self.status = options[:status] || 200
    self.content_type = options[:content_type] || 'text/html; charset=utf-8'
    self.headers['Content-Length'] = options[:text].bytesize.to_s
    self.response_body = options[:text]
  end
end
