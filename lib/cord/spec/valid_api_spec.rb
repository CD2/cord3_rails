module Cord
  module Spec
    def self.create_valid_api_spec
      ::RSpec.shared_examples 'a valid cord api' do
        next if described_class.abstract? || described_class.static?

        factory_name = described_class.resource_name.singularize
        factory_failed = false

        ::ActiveRecord::Base.transaction do
          begin
            ::FactoryBot.create(factory_name)
          rescue => e
            if e.is_a?(ArgumentError) && e.message.match(/Factory not registered: #{factory_name}/)
              pending "has a factory called '#{factory_name}'"
            else
              it 'has a valid factory' do
                raise e
              end
            end
            factory_failed = true
          end
          raise ::ActiveRecord::Rollback
        end

        next if factory_failed

        let!(:record) { ::FactoryBot.create(factory_name) }

        before(:all) do
          @action_on_error = Cord.action_on_error
          Cord.action_on_error = :raise
        end

        after(:all) { Cord.action_on_error = @action_on_error }

        context 'ignoring default scopes' do
          before(:all) do
            @disable_default_scopes = Cord.disable_default_scopes
            Cord.disable_default_scopes = true
            @scopes = described_class.scopes.dup
            described_class.scopes = {}
            described_class.scope :all
            described_class.scope(:none) { |driver| driver.where('FALSE') }
          end

          after(:all) do
            Cord.disable_default_scopes = @disable_default_scopes
            described_class.scopes = @scopes
          end

          it 'can render an id' do
            expect(subject.ids(:all).map(&:to_s)).to include(record.id.to_s)
          end

          it 'returns an empty array for empty scopes' do
            expect(subject.ids :none).to be_empty
          end

          it 'can render a record' do
            expect(subject.records([record.id]).pluck(:id).map(&:to_s)).to include(record.id.to_s)
          end

          it 'returns a RecordNotFound error given a missing id' do
            expect { subject.records(['_']) }.to raise_error(RecordNotFound)
          end

          it 'can render every defined attribute' do
            attributes = described_class.attributes.keys
            result = subject.records([record.id], attributes: attributes).first.keys
            expect(result).to include *attributes
          end

          it 'can perform every defined macro without error' do
            macros = described_class.macros.keys
            expect { subject.records([record.id], attributes: macros) }.to_not raise_error
          end
        end

        it 'can render every defined scope without error' do
          scopes = described_class.scopes.keys
          scopes.each do |scope|
            expect { subject.ids scope }.to_not raise_error
          end
        end

        it 'can apply all its sorts without error' do
          sorts = described_class.attributes.keys.select do |k|
            described_class.meta_attributes.dig(k, :sql) &&
            described_class.meta_attributes.dig(k, :sortable)
          end

          sorts.each do |sort|
            expect { subject.ids :all, sort: "#{sort} ASC" }.to_not raise_error
            expect { subject.ids :all, sort: "#{sort} DESC" }.to_not raise_error
          end
        end

        it 'can be searched without error' do
          expect { subject.ids :all, search: 'term' }.to_not raise_error
        end
      end
    end
  end
end
