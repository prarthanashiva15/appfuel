module Appfuel::Repository
  RSpec.describe Mapper do

    context '#initialize' do
      it 'initalizes with the container root name' do
        mapper = create_mapper('foo')
        expect(mapper.container_root_name).to eq('foo')
      end

      it 'allows you to manually load your own map' do
        map = {}
        mapper = create_mapper('foo', map)
        expect(mapper.map).to eq(map)
      end

      it 'fails when map is not a hash' do
        msg = 'repository mappings must be a hash'
        expect {
          create_mapper('foo', 'bar')
        }.to raise_error(RuntimeError, msg)
      end
    end

    context '#map' do
      it 'loads the map from the app container when none is given' do
        root = 'foo'
        map  = {}
        container = build_container(repository_mappings: map)
        expect(Appfuel).to receive(:app_container).with(root) { container }
        mapper = create_mapper(root)
        expect(mapper.map).to eq(map)
      end
    end

    context 'entity?' do
      it 'returns false when entity is not registered' do
        map = {}
        mapper = create_mapper('foo', map)

        expect(mapper.entity?('foo.bar')).to be false
      end

      it 'returns true when entity is registered' do
        map = {'foo.bar' => {}}
        mapper = create_mapper('foo', map)
        expect(mapper.entity?('foo.bar')).to be true
      end
    end

    context 'entity_attr?' do
      it 'returns false when entity is not registered' do
        map = {}
        mapper = create_mapper('my_root', map)
        expect(mapper.entity_attr?('foo.bar', 'id')).to be false
      end

      it 'returns false when entity exists but attr does not' do
        map = {'foo.bar' => {}}
        mapper = create_mapper('my_root', map)
        expect(mapper.entity_attr?('foo.bar', 'baz')).to be false
      end

      it 'returns true when entity exists and attr exists' do
        map = {'foo.bar' => {'id' => 'some entry'}}
        mapper = create_mapper('my_root', map)
        expect(mapper.entity_attr?('foo.bar', 'id')).to be true
      end
    end

    context 'find' do
      it 'finds an existing entry' do
        entry = 'some entry, object does not matter'
        map = {'foo.bar' => {'id' => entry}}
        mapper = create_mapper('my_root', map)
        expect(mapper.find('foo.bar', 'id')).to eq entry
      end

      it 'fails when entry does not exist' do
        map = {}
        mapper = create_mapper('my_root', map)
        msg = 'Entity (foo.bar) is not registered'
        expect {
          mapper.find('foo.bar', 'id')
        }.to raise_error(RuntimeError, msg)
      end

      it 'fails when attr does not exist' do
        map = {'foo.bar' => {}}
        mapper = create_mapper('my_root', map)
        msg = 'Entity (foo.bar) attr (baz) is not registered'
        expect {
          mapper.find('foo.bar', 'baz')
        }.to raise_error(RuntimeError, msg)
      end
    end

    context '.each_entity_attr' do
      it 'yields each entry for a mapped domain entity' do

        entry1 = 'first entry, object does not matter'
        map = {
          'foo.bar' => {
            'attr_1' => entry1
          }
        }

        mapper = create_mapper('my_root', map)
        expect {|b|
          mapper.each_entity_attr('foo.bar', &b)
        }.to yield_with_args(entry1)
      end

      it 'yields two entries' do
        entry1 = 'first entry, object does not matter'
        entry2 = 'second entry, object does not matter'
        map = {
          'foo.bar' => {
            'attr_1' => entry1,
            'attr_2' => entry2
          }
        }

        mapper = create_mapper('my_root', map)

        expect {|b|
          mapper.each_entity_attr('foo.bar', &b)
        }.to yield_successive_args(entry1, entry2)
      end
    end

    context '.storage_attr_mapped?' do
      it 'returns false when the column is not mapped' do
        entry = instance_double(MappingEntry)
        allow(entry).to receive(:storage_attr).with(no_args) { 'not_baz' }
        map = {
          'foo.bar' => {
            'bif' => entry
          }
        }
        mapper = create_mapper('my_root', map)
        expect(mapper.storage_attr_mapped?('foo.bar', 'baz')).to be false
      end

      it 'returns true when the column is mapped' do
        entry = instance_double(MappingEntry)
        allow(entry).to receive(:storage_attr).with(no_args) { 'bar_id' }
        map = {
          'foo.bar' => {
            'bif' => entry
          }
        }
        mapper = create_mapper('my_root', map)
        expect(mapper.storage_attr_mapped?('foo.bar', 'bar_id')).to be true
      end

      it 'fails when entity is not mapped' do
        msg = 'Entity (foo.bar) is not registered'
        mapper = create_mapper('my_root', {})
        expect {
          mapper.storage_attr_mapped?('foo.bar', 'bar_id')
        }.to raise_error(RuntimeError, msg)
      end
    end

    context '#storage_attr' do
      it 'fails when entity is not mapped' do
        msg = 'Entity (foo.bar) is not registered'
        mapper = create_mapper('my_root', {})
        expect {
          mapper.storage_attr('foo.bar', 'id')
        }.to raise_error(RuntimeError, msg)
      end

      it 'fails when the entity attribute is not mapped' do
        map = {'foo.bar' => {}}
        mapper = create_mapper('my_root', map)
        msg = 'Entity (foo.bar) attr (baz) is not registered'
        expect {
          mapper.storage_attr('foo.bar', 'baz')
        }.to raise_error(RuntimeError, msg)
      end

      it 'returns the attribute value mapped' do
        entry = instance_double(MappingEntry)
        attr_value = 'some value'
        allow(entry).to receive(:storage_attr).with(no_args) { attr_value }
        map = {
          'foo.bar' => {
            'bif' => entry
          }
        }
        mapper = create_mapper('my_root', map)
        expect(mapper.storage_attr('foo.bar', 'bif')).to eq(attr_value)
      end
    end

    context '#storage_class_from_entry' do
      it 'fails when the storage type is not supported' do
        entry = instance_double(MappingEntry)
        type  = :db
        allow(entry).to receive(:storage?).with(type) { false }
        mapper = create_mapper('my_root')
        msg = 'No (db) storage has been mapped'
        expect {
          mapper.storage_class_from_entry(entry, type)
        }.to raise_error(msg)
      end

      it "fails when the mapper and entry container name's dont match" do
        type  = :db
        entry = instance_double(MappingEntry)
        entry_container_name = 'bar'

        allow(entry).to receive(:storage?).with(type) { true }
        allow(entry).to(
          receive(:container_name).with(no_args) { entry_container_name }
        )
        mapper = create_mapper('foo')
        msg = 'You can not access a mapping outside of this container ' +
              '(mapper: foo, entry: bar)'

        expect {
          mapper.storage_class_from_entry(entry, type)
        }.to raise_error(msg)
      end

      it 'uses the entry storage key to retrieve class from app container' do
        type      = :db
        key       = 'features.bar.db.user'
        entry     = instance_double(MappingEntry)
        container = double('some container')
        db_class  = 'some active record model'
        container_name = 'foo'

        allow(entry).to receive(:storage?).with(type) { true }
        allow(entry).to receive(:storage).with(type) { key }
        allow(entry).to(
          receive(:container_name).with(no_args) { container_name }
        )

        allow(container).to receive(:[]).with(key) { db_class }
        allow(Appfuel).to(
          receive(:app_container).with(container_name) { container }
        )

        mapper = create_mapper(container_name)
        expect(mapper.storage_class_from_entry(entry, type)).to eq(db_class)
      end
    end

    context '#storage_class' do
      it 'finds the entry then delagates to #storage_class_from_entry' do
        domain_name = 'bar.baz'
        domain_attr = 'id'
        type        = :db
        entry       = instance_double(MappingEntry)
        db_class    = 'some active record model'
        mapper      = create_mapper('foo')

        expect(mapper).to(
          receive(:find).with(domain_name, domain_attr) { entry }
        )
        expect(mapper).to(
          receive(:storage_class_from_entry).with(entry, type) { db_class }
        )

        result = mapper.storage_class(domain_name, domain_attr, type)
        expect(result).to eq(db_class)
      end
    end

    context '#undefined?' do
      it 'returns true when the value given is Types::Undefined' do
        value  = Types::Undefined
        mapper = create_mapper('foo')
        expect(mapper.undefined?(value)).to be(true)
      end

      it 'returns false when the value given is not Types::Undefined' do
        value  = 'some value'
        mapper = create_mapper('foo')
        expect(mapper.undefined?(value)).to be(false)
      end
    end

    context '#resolve_entity_value' do
      it 'gets the top level attribute of the domain' do
        value = 123456
        domain = Object.new
        domain.define_singleton_method(:id) do
          value
        end
        domain_attr = 'id'

        mapper = create_mapper('foo')
        expect(mapper.resolve_entity_value(domain, domain_attr)).to eq(value)
      end

      it 'traverses nested objects to get the value' do
        value = 123456
        role = Object.new
        role.define_singleton_method(:id) do
          value
        end
        user = Object.new
        user.define_singleton_method(:role) do
          role
        end
        member = Object.new
        member.define_singleton_method(:user) do
          user
        end
        group = Object.new
        group.define_singleton_method(:member) do
          member
        end
        domain = Object.new
        domain.define_singleton_method(:group) do
          group
        end
        domain_attr = 'group.member.user.role.id'

        mapper = create_mapper('foo')
        expect(mapper.resolve_entity_value(domain, domain_attr)).to eq(value)
      end
    end

    context '#create_entity_hash' do
      it 'creates a basic hash for a non nested attribute' do
        domain_attr = 'id'
        value  = 12345
        hash   = {'id' => value}
        mapper = create_mapper('foo')
        expect(mapper.create_entity_hash(domain_attr, value)).to eq(hash)
      end

      it 'creates a nested hash for an attribute with objects' do
        domain_attr = 'group.member.user.role.id'
        value = 12345
        hash  = {
          'group' => {
            'member' => {
              'user' => {
                'role' => {
                  'id' => value
                }
              }
            }
          }
        }
        mapper = create_mapper('foo')
        expect(mapper.create_entity_hash(domain_attr, value)).to eq(hash)
      end
    end

    context '#entity_value' do
      it 'resolves the entity value' do
        domain = double('some domain')
        domain_attr = 'foo.bar.baz.id'
        entry  = instance_double(MappingEntry)
        value  = 123
        mapper = create_mapper('foo')
        expect(mapper).to(
          receive(:resolve_entity_value).with(domain, domain_attr) { value }
        )
        allow(entry).to receive(:computed_attr?).with(no_args) { false }
        allow(entry).to receive(:domain_attr).with(no_args) { domain_attr }
        expect(mapper.entity_value(domain, entry)).to eq(value)
      end
    end

    def default_entry_data(data = {})
      default = {
        domain: 'foo.bar',
        domain_attr: 'id',
        storage_class: {db: 'bar'},
        storage_attr: 'bar_id'
      }

      default.merge(data)
    end

    def create_entry(data)
      MappingEntry.new(data)
    end

    def create_mapper(root_name, map = nil)
      Mapper.new(root_name, map)
    end
  end
end
