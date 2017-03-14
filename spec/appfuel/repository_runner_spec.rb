module Appfuel
  RSpec.describe RepositoryRunner do
    context '#new' do
      it 'requires the repo namespace and criteria class' do
        repo_ns  = 'Foo::Bar'
        criteria = Criteria
        runner   = RepositoryRunner.new(repo_ns, criteria)
        expect(runner.repo_namespace).to eq(repo_ns)
        expect(runner.criteria_class).to eq(criteria)
      end
    end

    context '#exists?' do
      it 'fails when repository does not exist' do
        repo_ns  = 'Foo::Bar'
        criteria = Criteria
        runner   = RepositoryRunner.new(repo_ns, criteria)
        msg = 'RepositoryRunner: failed - repo Foo::Bar::DomainRepository not defined'
        expect {
          runner.exists?('domain', id: 123)
        }.to raise_error(RuntimeError, msg)
      end

      it 'delegates exists to repo.exists? passing the criteria' do
        repo_ns         = 'Foo::Bar'
        criteria        = Criteria
        runner          = RepositoryRunner.new(repo_ns, criteria)
        repo_class_name = 'Foo::Bar::DomainRepository'
        repo_class      = class_double(Repository)
        repo            = instance_double(Repository)
        criteria        = instance_double(Criteria)
        entity_key      = 'domain'
        attribute       = 'id'
        value           = true

        allow_const_defined(Kernel, repo_class_name, true)
        allow_const_get(Kernel, repo_class_name, repo_class)
        allow(repo_class).to receive(:new).with(no_args) { repo }

        allow(Criteria).to receive(:new).with(entity_key, {}) { criteria }
        allow(criteria).to receive(:exists).with(attribute, value) { criteria }
        allow(criteria).to receive(:repo_name).with(no_args) { "DomainRepository" }
        allow(repo).to receive(:exists?).with(criteria) { true }

        expect(runner.exists?(entity_key, attribute => value)).to eq(true)
      end
    end

    context '#query' do
      it 'fails when repository does not exist' do
        repo_ns = 'Foo::Bar'
        criteria_class = Criteria
        runner = RepositoryRunner.new(repo_ns, criteria_class)
        msg = 'RepositoryRunner: failed - repo Foo::Bar::DomainRepository not defined'

        criteria = criteria_class.new('domain').where('id', eq: 123)
        expect {
          runner.query(criteria)
        }.to raise_error(RuntimeError, msg)
      end
    end
  end
end