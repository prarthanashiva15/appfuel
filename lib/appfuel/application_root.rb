module Appfuel
  module ApplicationRoot
    # Initialize Appfuel by creating an application container for the
    # app represented by the root module passed in. The app container is
    # a dependency injection container that is used thought the app.
    #
    # @raises ArgumentError when root module does not exist
    #
    # @param params [Hash]
    # @option root [Module] root module of the application
    # @option app_name [String, Symbol] key to store container in appfuel
    #
    # @return [Dry::Container]
    def setup_appfuel(params = {})
      app_container       = params[:app_container] || Dry::Container.new
      framework_container = Appfuel.framework_container

      app_container = build_app_container(params, app_container)
      app_name = handle_app_name(params, app_container, framework_container)

      framework_container.register(app_name, app_container)

      if params.key?(:after_setup)
        handle_after_setup(params[:after_setup], app_container)
      end

      app_container
    end

    def handle_after_setup(hook, container)
      unless hook.respond_to?(:call)
        fail ArgumentError, "After setup hook (:after_setup) must " +
          "implement :call, which takes the di container as its only arg"
      end
      hook.call(container)
    end

    # Determine the app name for input params or the parsing the root
    # module if no params are specified. This also handles assigning
    # the default app name so that you don't have give Appfuel the
    # name everytime you want to deal with the container
    #
    # @param root [Module] The root module of the application
    # @param params [Hash] input params from setup
    # @option app_name [String] optional
    # @option default_app [Bool] force the assignment of default name
    #
    # @return [String]
    def handle_app_name(params, app_container, framework_container)
      app_name = params.fetch(:app_name) {
        app_container[:root].to_s.underscore
      }

      if params[:default_app] == true || !Appfuel.default_app?
        framework_container.register(:default_app_name, app_name)
      end

      app_name.to_s
    end

    # Initializes the application container with:
    #
    # Application Container
    #   root: This is the root module that holds the namespaces for all
    #         features, actions, commands etc. This is required.
    #
    #   root_path: This is the root path of app where the source code
    #              lives. We use this to autoload this features. This
    #              is still under design so it might not stay.
    #
    #   config_definition: This is the definition object that we use to
    #                      build out the configuration hash. This is optional
    #
    #   initializers: This is an array that hold all the initializers to be
    #                 run. This builder will handle creating the array. It is
    #                 populated via appfuel dsl Appfuel::Initialize#define
    #
    #   global.validators: This is a hash that holds all global validators.
    #                      this builder will handle creating the hash. It is
    #                      populated via appfuel dsl
    #                      Appfuel::Validator#global_validator
    #
    #   global.domain_builders:
    #   global.presenters
    #
    # @param root [Module] the root module of the application
    # @param container [Dry::Container] dependency injection container
    # @return [Dry::Container]
    def build_app_container(params, container = Dry::Container.new)
      root = params.fetch(:root) {
        fail ArgumentError, "Root module (:root) is required"
      }

      root_path = params.fetch(:root_path) {
        fail ArgumentError, "Root path (:root_path) is required"
      }

      container.register(:root, root)
      container.register(:root_path, root_path)
      if params.key?(:config_definition)
        container.register(:config_definition, params[:config_definition])
      end

      container.register(:initializers, ThreadSafe::Array.new)

      ns = Dry::Container::Namespace.new('global') do
        register('validators') { {} }
        register('domain_builders') { {} }
        register('presenters') { {} }
      end

      container.import(ns)

      container
    end

    def bootstrap(overrides: {}, env: ENV)
      Initialize.run(overrides: overrides, env: env)
    end

    def dispatch(route, inputs = {})
      container = Appfuel.app_container
      request   = Request.new(route, inputs)
      root      = container[:root_module]
      unless root.const_defined?(request.feature)
        class_name = "#{root.to_s.underscore}/#{feature.underscore}"
        require class_name
      end
      ap root.const_defined?(request.feature)
    end
  end
end