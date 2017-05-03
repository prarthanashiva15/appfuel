module Appfuel
  module Repository
    class Base
      extend Appfuel::Application::ContainerKey
      extend Appfuel::Application::ContainerClassRegistration

      class << self
        attr_writer :mapper
        def inherited(klass)
          register_container_class(klass)
        end

        def mapper
          @mapper ||= create_mapper
        end

        def create_mapper(maps = nil)
          Mapper.new(maps)
        end

        def app_container
          Appfuel.app_container(container_root_name)
        end
      end

      def mapper
        self.class.mapper
      end

      def to_storage(entity)
        mapper.to_storage(entity)
      end

      def build(domain_name, storage_interface, type, inputs = {})
        builder = find_entity_builder(domain_name, type)
        builder.call(storage_interface, inputs)
      end

      # features.membership.presenters.hash.user
      # global.presenters.user
      def find_entity_builder(domain_name, type)
        key = qualify_container_key(domain_name, "presenters.#{type}")

        container = app_container
        unless container.key?(key)
          return ->(data, inputs = {}) {
            hash = mapper.to_entity_hash(domain_name, data)
            domain_key = qualify_container_key(domain_name, "domains")
            app_container[domain_key].new(hash)
          }
        end

        container[key]
      end


      private
      def app_container
        self.class.app_container
      end

      def qualify_container_key(domain_name, type)
        self.class.qualify_container_key(domain_name, type)
      end
    end
  end
end
