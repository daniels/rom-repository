RSpec.describe ROM::Repository, '#command' do
  include_context 'database'
  include_context 'relations'
  include_context 'repo'

  context 'accessing custom command from the registry' do
    before do
      configuration.commands(:users) do
        define(:upsert, type: ROM::SQL::Commands::Create)
        define(:create)
      end

      configuration.commands(:tasks) do
        define(:create)
      end
    end

    it 'returns registered command' do
      expect(repo.command(:users).upsert).to be(rom.command(:users).upsert)
      expect(repo.command(:users)[:upsert]).to be(rom.command(:users).upsert)
    end

    it 'exposes command builder DSL' do
      command = repo.command.create(user: :users) { |user| user.create(:tasks) }

      expect(command).to be_instance_of(ROM::Command::Graph)
    end
  end

  context ':create' do
    it 'builds Create command for a relation' do
      create_user = repo.command(create: :users)

      user = create_user.call(name: 'Jane Doe')

      expect(user.id).to_not be(nil)
      expect(user.name).to eql('Jane Doe')
    end

    it 'caches commands' do
      create_user = -> { repo.command(create: :users) }

      expect(create_user.()).to be(create_user.())
    end

    it 'builds Create command for a relation graph with one-to-one' do
      create_user = repo.command(
        :create,
        repo.users.combine_children(one: repo.tasks)
      )

      user = create_user.call(name: 'Jane Doe', task: { title: 'Task one' })

      expect(user.id).to_not be(nil)
      expect(user.name).to eql('Jane Doe')
      expect(user.task.title).to eql('Task one')
    end

    it 'builds Create command for a deeply nested relation graph' do
      create_user = repo.command(
        :create,
        repo.users.combine_children(one: repo.tasks.combine_children(many: repo.tags))
      )

      user = create_user.call(
        name: 'Jane Doe', task: { title: 'Task one', tags: [{ name: 'red' }] }
      )

      expect(user.id).to_not be(nil)
      expect(user.name).to eql('Jane Doe')
      expect(user.task.title).to eql('Task one')
      expect(user.task.tags).to be_instance_of(Array)
      expect(user.task.tags.first.name).to eql('red')
    end

    it 'builds Create command for a relation graph with one-to-many' do
      create_user = repo.command(
        :create,
        repo.users.combine_children(many: repo.tasks)
      )

      user = create_user.call(name: 'Jane Doe', tasks: [{ title: 'Task one' }])

      expect(user.id).to_not be(nil)
      expect(user.name).to eql('Jane Doe')
      expect(user.tasks).to be_instance_of(Array)
      expect(user.tasks.first.title).to eql('Task one')
    end

    it 'builds Create command for a deeply nested graph with one-to-many' do
      create_user = repo.command(
        :create,
        repo.aggregate(many: repo.tasks.combine_children(many: repo.tags))
      )

      user = create_user.call(
        name: 'Jane',
        tasks: [{ title: 'Task', tags: [{ name: 'red' }]}]
      )

      expect(user.id).to_not be(nil)
      expect(user.name).to eql('Jane')
      expect(user.tasks).to be_instance_of(Array)
      expect(user.tasks.first.title).to eql('Task')
      expect(user.tasks.first.tags).to be_instance_of(Array)
      expect(user.tasks.first.tags.first.name).to eql('red')
    end

    it 'builds Create command for a deeply nested graph with many-to-one & one-to-many' do
      create_user = repo.command(
        :create,
        repo.aggregate(one: repo.tasks.combine_children(many: repo.tags))
      )

      user = create_user.call(
        name: 'Jane', task: { title: 'Task', tags: [{ name: 'red' }, { name: 'blue' }] }
      )

      expect(user.id).to_not be(nil)
      expect(user.name).to eql('Jane')
      expect(user.task.title).to eql('Task')
      expect(user.task.tags).to be_instance_of(Array)
      expect(user.task.tags.size).to be(2)
      expect(user.task.tags[0].name).to eql('red')
      expect(user.task.tags[1].name).to eql('blue')
    end

    it 'builds Create command for a deeply nested graph with many-to-one' do
      create_user = repo.command(
        :create,
        repo.aggregate(one: repo.tasks.combine_children(one: repo.tags))
      )

      user = create_user.call(
        name: 'Jane', task: { title: 'Task', tag: { name: 'red' } }
      )

      expect(user.id).to_not be(nil)
      expect(user.name).to eql('Jane')
      expect(user.task.id).to_not be(nil)
      expect(user.task.title).to eql('Task')
      expect(user.task.tag.id).to_not be(nil)
      expect(user.task.tag.name).to eql('red')
    end

    context 'relation with a custom dataset name' do
      let(:repo) { Class.new(ROM::Repository[:comments]).new(rom) }

      it 'allows configuring a create command' do
        create_comment = repo.command(create: :comments)

        comment = create_comment.(author: 'gerybabooma', body: 'DIS GUY MUST BE A ALIEN OR SUTIN')

        expect(comment.message_id).to eql(1)
        expect(comment.author).to eql('gerybabooma')
        expect(comment.body).to eql('DIS GUY MUST BE A ALIEN OR SUTIN')
      end
    end
  end

  context ':update' do
    it 'builds Update command for a relation' do
      repo.users.insert(id: 3, name: 'Jane')

      update_user = repo.command(:update, repo.users)

      user = update_user.by_id(3).call(name: 'Jane Doe')

      expect(user.id).to be(3)
      expect(user.name).to eql('Jane Doe')
    end
  end

  context ':delete' do
    it 'builds Delete command for a relation' do
      repo.users.insert(id: 3, name: 'Jane')

      delete_user = repo.command(:delete, repo.users)

      delete_user.by_id(3).call

      expect(repo.users.by_id(3).one).to be(nil)
    end
  end

  it 'raises error when unsupported type is used' do
    expect { repo.command(:oops, repo.users) }.to raise_error(
      ArgumentError, /oops/
    )
  end
end
