require 'spec_helper'

describe Chewy::Query do
  before do
    Chewy.client.indices.delete index: '*'
  end

  before do
    stub_index(:products) do
      define_type :product do
        field :name, :age
      end
      define_type :city
      define_type :country
    end
  end

  subject { described_class.new(ProductsIndex) }

  context 'unexistent index' do
    specify { subject.to_a.should == [] }
  end

  context 'integration' do
    let(:products) { 3.times.map { |i| {id: i.next.to_s, name: "Name#{i.next}", age: 10 * i.next}.stringify_keys! } }
    let(:cities) { 3.times.map { |i| {id: i.next.to_s}.stringify_keys! } }
    let(:countries) { 3.times.map { |i| {id: i.next.to_s}.stringify_keys! } }
    before do
      ProductsIndex::Product.import!(products.map { |h| double(h) })
      ProductsIndex::City.import!(cities.map { |h| double(h) })
      ProductsIndex::Country.import!(countries.map { |h| double(h) })
    end

    specify { subject.count.should == 9 }
    specify { subject.first._data.should be_a Hash }
    specify { subject.limit(6).count.should == 6 }
    specify { subject.offset(6).count.should == 3 }
    specify { subject.query(match: {name: 'name3'}).highlight(fields: {name: {}}).first.name.should == '<em>Name3</em>' }
    specify { subject.query(match: {name: 'name3'}).highlight(fields: {name: {}}).first._data['_source']['name'].should == 'Name3' }
    specify { subject.types(:product).count.should == 3 }
    specify { subject.types(:product, :country).count.should == 6 }
    specify { subject.filter(term: {age: 10}).count.should == 1 }
    specify { subject.query(term: {age: 10}).count.should == 1 }
  end

  describe '#==' do
    let(:data) { 3.times.map { |i| {id: i.next.to_s, name: "Name#{i.next}", age: 10 * i.next}.stringify_keys! } }
    before { ProductsIndex::Product.import!(data.map { |h| double(h) }) }

    specify { subject.query(match: 'hello').should == subject.query(match: 'hello') }
    specify { subject.query(match: 'hello').should_not == subject.query(match: 'world') }
    specify { subject.limit(10).should == subject.limit(10) }
    specify { subject.limit(10).should_not == subject.limit(11) }
    specify { subject.limit(2).should == subject.limit(2).to_a }
  end

  describe '#query_mode' do
    specify { subject.query_mode(:should).should be_a described_class }
    specify { subject.query_mode(:should).should_not == subject }
    specify { subject.query_mode(:should).criteria.options.should include(query_mode: :should) }
    specify { expect { subject.query_mode(:should) }.not_to change { subject.criteria.options } }
  end

  describe '#filter_mode' do
    specify { subject.filter_mode(:or).should be_a described_class }
    specify { subject.filter_mode(:or).should_not == subject }
    specify { subject.filter_mode(:or).criteria.options.should include(filter_mode: :or) }
    specify { expect { subject.filter_mode(:or) }.not_to change { subject.criteria.options } }
  end

  describe '#post_filter_mode' do
    specify { subject.post_filter_mode(:or).should be_a described_class }
    specify { subject.post_filter_mode(:or).should_not == subject }
    specify { subject.post_filter_mode(:or).criteria.options.should include(post_filter_mode: :or) }
    specify { expect { subject.post_filter_mode(:or) }.not_to change { subject.criteria.options } }
  end

  describe '#boost_mode' do
    specify { subject.boost_mode(:replace).should be_a described_class }
    specify { subject.boost_mode(:replace).should_not == subject }
    specify { subject.boost_mode(:replace).criteria.options.should include(boost_mode: :replace) }
    specify { expect { subject.boost_mode(:replace) }.not_to change { subject.criteria.options } }
  end

  describe '#score_mode' do
    specify { subject.score_mode(:first).should be_a described_class }
    specify { subject.score_mode(:first).should_not == subject }
    specify { subject.score_mode(:first).criteria.options.should include(score_mode: :first) }
    specify { expect { subject.score_mode(:first) }.not_to change { subject.criteria.options } }
  end

  describe '#limit' do
    specify { subject.limit(10).should be_a described_class }
    specify { subject.limit(10).should_not == subject }
    specify { subject.limit(10).criteria.request_options.should include(size: 10) }
    specify { expect { subject.limit(10) }.not_to change { subject.criteria.request_options } }
  end

  describe '#offset' do
    specify { subject.offset(10).should be_a described_class }
    specify { subject.offset(10).should_not == subject }
    specify { subject.offset(10).criteria.request_options.should include(from: 10) }
    specify { expect { subject.offset(10) }.not_to change { subject.criteria.request_options } }
  end

  describe '#script_score' do
    specify { subject.script_score('23').should be_a described_class }
    specify { subject.script_score('23').should_not == subject }
    specify { subject.script_score('23').criteria.scores.should == [ { script_score: { script: '23' } } ] }
    specify { expect { subject.script_score('23') }.not_to change { subject.criteria.scores } }
    specify { subject.script_score('23', filter: { foo: :bar}).criteria.scores.should == [{ script_score: { script: '23' }, filter: { foo: :bar } }] }
  end

  describe '#boost_factor' do
    specify { subject.boost_factor('23').should be_a described_class }
    specify { subject.boost_factor('23').should_not == subject }
    specify { subject.boost_factor('23').criteria.scores.should == [ { boost_factor: 23  } ] }
    specify { expect { subject.boost_factor('23') }.not_to change { subject.criteria.scores } }
    specify { subject.boost_factor('23', filter: { foo: :bar}).criteria.scores.should == [{ boost_factor: 23, filter: { foo: :bar } }] }
  end

  describe '#random_score' do
    specify { subject.random_score('23').should be_a described_class }
    specify { subject.random_score('23').should_not == subject }
    specify { subject.random_score('23').criteria.scores.should == [ { random_score: { seed: 23 } } ] }
    specify { expect { subject.random_score('23') }.not_to change { subject.criteria.scores } }
    specify { subject.random_score('23', filter: { foo: :bar}).criteria.scores.should == [{ random_score: { seed: 23 }, filter: { foo: :bar } }] }
  end

  describe '#field_value_score' do
    specify { subject.field_value_factor(field: :boost).should be_a described_class }
    specify { subject.field_value_factor(field: :boost).should_not == subject }
    specify { subject.field_value_factor(field: :boost).criteria.scores.should == [ { field_value_factor: { field: :boost } } ] }
    specify { expect { subject.field_value_factor(field: :boost) }.not_to change { subject.criteria.scores } }
    specify { subject.field_value_factor({ field: :boost }, filter: { foo: :bar}).criteria.scores.should == [{ field_value_factor: { field: :boost }, filter: { foo: :bar } }] }
  end

  describe '#decay' do
    specify { subject.decay(:gauss, :field).should be_a described_class }
    specify { subject.decay(:gauss, :field).should_not == subject }
    specify { subject.decay(:gauss, :field).criteria.scores.should == [ {
      gauss: {
        field: {
          origin: 0,
          scale: 1,
          offset: 0,
          decay: 0.1
        }
      }
    }] }
    specify { expect { subject.decay(:gauss, :field) }.not_to change { subject.criteria.scores } }
    specify {
      subject.decay(:gauss, :field,
                    origin: '11, 12',
                    scale: '2km',
                    offset: '5km',
                    decay: 0.4,
                    filter: { foo: :bar }).criteria.scores.should == [
        {
          gauss: {
            field: {
              origin: '11, 12',
              scale: '2km',
              offset: '5km',
              decay: 0.4
            }
          },
          filter: { foo: :bar }
        }
      ]
    }
  end

  describe '#facets' do
    specify { subject.facets(term: {field: 'hello'}).should be_a described_class }
    specify { subject.facets(term: {field: 'hello'}).should_not == subject }
    specify { subject.facets(term: {field: 'hello'}).criteria.facets.should include(term: {field: 'hello'}) }
    specify { expect { subject.facets(term: {field: 'hello'}) }.not_to change { subject.criteria.facets } }

    context 'results' do
      before { stub_model(:city) }
      let(:cities) { 10.times.map { |i| City.create! name: "name#{i}", rating: i % 3 } }

      before do
        stub_index(:cities) do
          define_type :city do
            field :rating, type: 'integer'
          end
        end
      end

      before { CitiesIndex::City.import! cities }

      specify { CitiesIndex.facets.should == {} }
      specify { CitiesIndex.facets(ratings: {terms: {field: 'rating'}}).facets.should == {
        'ratings' => {
          '_type' => 'terms', 'missing' => 0, 'total' => 10, 'other' => 0,
          'terms' => [
            {'term' => 0, 'count' => 4},
            {'term' => 2, 'count' => 3},
            {'term' => 1, 'count' => 3}
          ]
        }
      } }
    end
  end

  describe '#aggregations' do
    specify { subject.aggregations(aggregation1: {field: 'hello'}).should be_a described_class }
    specify { subject.aggregations(aggregation1: {field: 'hello'}).should_not == subject }
    specify { subject.aggregations(aggregation1: {field: 'hello'}).criteria.aggregations.should include(aggregation1: {field: 'hello'}) }
    specify { expect { subject.aggregations(aggregation1: {field: 'hello'}) }.not_to change { subject.criteria.aggregations } }

    context 'results' do
      before { stub_model(:city) }
      let(:cities) { 10.times.map { |i| City.create! name: "name#{i}", rating: i % 3 } }

      context do
        before do
          stub_index(:cities) do
            define_type :city do
              field :rating, type: 'integer'
            end
          end
        end

        before { CitiesIndex::City.import! cities }

        specify { CitiesIndex.aggregations.should == {} }
        specify { CitiesIndex.aggregations(ratings: {terms: {field: 'rating'}}).aggregations.should == {
          'ratings' => {
            'buckets' => [
              {'key' => 0, 'key_as_string' => '0', 'doc_count' => 4},
              {'key' => 1, 'key_as_string' => '1', 'doc_count' => 3},
              {'key' => 2, 'key_as_string' => '2', 'doc_count' => 3}
            ]
          }
        } }
      end
    end
  end

  describe '#suggest' do
    specify { subject.suggest(name1: {text: 'hello', term: {field: 'name'}}) }
    specify { subject.suggest(name1: {text: 'hello'}).should_not == subject }
    specify { expect(subject.suggest(name1: {text: 'hello'}).criteria.suggest).to include(name1: {text: 'hello'}) }
    specify { expect { subject.suggest(name1: {text: 'hello'}) }.not_to change { subject.criteria.suggest } }

    context 'results' do
      before { stub_model(:city) }
      let(:cities) { 10.times.map { |i| City.create! name: "name#{i}" } }

      context do
        before do
          stub_index(:cities) do
            define_type :city do
              field :name
            end
          end
        end

        before { CitiesIndex::City.import! cities }

        specify { CitiesIndex.suggest.should == {} }
        specify { CitiesIndex.suggest(name: {text: 'name', term: {field: 'name'}}).suggest.should == {
          'name' => [
            {'text' => 'name', 'offset' => 0, 'length' => 4, 'options' => [
                {'text' => 'name0', 'score' => 0.75, 'freq' => 1},
                {'text' => 'name1', 'score' => 0.75, 'freq' => 1},
                {'text' => 'name2', 'score' => 0.75, 'freq' => 1},
                {'text' => 'name3', 'score' => 0.75, 'freq' => 1},
                {'text' => 'name4', 'score' => 0.75, 'freq' => 1}
              ]
            }
          ] }
        }
      end
    end
  end

  describe '#delete_all' do
    let(:products) { 3.times.map { |i| {id: i.next.to_s, name: "Name#{i.next}", age: 10 * i.next}.stringify_keys! } }
    let(:cities) { 3.times.map { |i| {id: i.next.to_s}.stringify_keys! } }
    let(:countries) { 3.times.map { |i| {id: i.next.to_s}.stringify_keys! } }

    before do
      ProductsIndex::Product.import!(products.map { |h| double(h) })
      ProductsIndex::City.import!(cities.map { |h| double(h) })
      ProductsIndex::Country.import!(countries.map { |h| double(h) })
    end

    specify { expect { subject.query(match: {name: 'name3'}).delete_all }.to change { ProductsIndex.total_count }.from(9).to(8) }
    specify { expect { subject.filter { age == [10, 20] }.delete_all }.to change { ProductsIndex.total_count }.from(9).to(7) }
    specify { expect { subject.types(:product).delete_all }.to change { ProductsIndex::Product.total_count }.from(3).to(0) }
    specify { expect { ProductsIndex.delete_all }.to change { ProductsIndex.total_count }.from(9).to(0) }
    specify { expect { ProductsIndex::City.delete_all }.to change { ProductsIndex.total_count }.from(9).to(6) }
  end

  describe '#none' do
    specify { subject.none.should be_a described_class }
    specify { subject.none.should_not == subject }
    specify { subject.none.criteria.should be_none }

    context do
      before { expect_any_instance_of(described_class).not_to receive(:_response) }

      specify { subject.none.to_a.should == [] }
      specify { subject.query(match: 'hello').none.to_a.should == [] }
      specify { subject.none.query(match: 'hello').to_a.should == [] }
    end
  end

  describe '#strategy' do
    specify { subject.strategy('query_first').should be_a described_class }
    specify { subject.strategy('query_first').should_not == subject }
    specify { subject.strategy('query_first').criteria.options.should include(strategy: 'query_first') }
    specify { expect { subject.strategy('query_first') }.not_to change { subject.criteria.options } }
  end

  describe '#query' do
    specify { subject.query(match: 'hello').should be_a described_class }
    specify { subject.query(match: 'hello').should_not == subject }
    specify { subject.query(match: 'hello').criteria.queries.should include(match: 'hello') }
    specify { expect { subject.query(match: 'hello') }.not_to change { subject.criteria.queries } }
  end

  describe '#filter' do
    specify { subject.filter(term: {field: 'hello'}).should be_a described_class }
    specify { subject.filter(term: {field: 'hello'}).should_not == subject }
    specify { expect { subject.filter(term: {field: 'hello'}) }.not_to change { subject.criteria.filters } }
    specify { subject.filter([{term: {field: 'hello'}}, {term: {field: 'world'}}]).criteria.filters
      .should == [{term: {field: 'hello'}}, {term: {field: 'world'}}] }

    specify { expect { subject.filter{ name == 'John' } }.not_to change { subject.criteria.filters } }
    specify { subject.filter{ name == 'John' }.criteria.filters.should == [{term: {'name' => 'John'}}] }
  end

  describe '#post_filter' do
    specify { subject.post_filter(term: {field: 'hello'}).should be_a described_class }
    specify { subject.post_filter(term: {field: 'hello'}).should_not == subject }
    specify { expect { subject.post_filter(term: {field: 'hello'}) }.not_to change { subject.criteria.post_filters } }
    specify { subject.post_filter([{term: {field: 'hello'}}, {term: {field: 'world'}}]).criteria.post_filters
      .should == [{term: {field: 'hello'}}, {term: {field: 'world'}}] }

    specify { expect { subject.post_filter{ name == 'John' } }.not_to change { subject.criteria.post_filters } }
    specify { subject.post_filter{ name == 'John' }.criteria.post_filters.should == [{term: {'name' => 'John'}}] }
  end

  describe '#order' do
    specify { subject.order(field: 'hello').should be_a described_class }
    specify { subject.order(field: 'hello').should_not == subject }
    specify { expect { subject.order(field: 'hello') }.not_to change { subject.criteria.sort } }

    specify { subject.order(:field).criteria.sort.should == [:field] }
    specify { subject.order([:field1, :field2]).criteria.sort.should == [:field1, :field2] }
    specify { subject.order(field: :asc).criteria.sort.should == [{field: :asc}] }
    specify { subject.order({field1: {order: :asc}, field2: :desc}).order([:field3], :field4).criteria.sort.should == [{field1: {order: :asc}}, {field2: :desc}, :field3, :field4] }
  end

  describe '#reorder' do
    specify { subject.reorder(field: 'hello').should be_a described_class }
    specify { subject.reorder(field: 'hello').should_not == subject }
    specify { expect { subject.reorder(field: 'hello') }.not_to change { subject.criteria.sort } }

    specify { subject.order(:field1).reorder(:field2).criteria.sort.should == [:field2] }
    specify { subject.order(:field1).reorder(:field2).order(:field3).criteria.sort.should == [:field2, :field3] }
    specify { subject.order(:field1).reorder(:field2).reorder(:field3).criteria.sort.should == [:field3] }
  end

  describe '#only' do
    specify { subject.only(:field).should be_a described_class }
    specify { subject.only(:field).should_not == subject }
    specify { expect { subject.only(:field) }.not_to change { subject.criteria.fields } }

    specify { subject.only(:field1, :field2).criteria.fields.should =~ ['field1', 'field2'] }
    specify { subject.only([:field1, :field2]).only(:field3).criteria.fields.should =~ ['field1', 'field2', 'field3'] }
  end

  describe '#only!' do
    specify { subject.only!(:field).should be_a described_class }
    specify { subject.only!(:field).should_not == subject }
    specify { expect { subject.only!(:field) }.not_to change { subject.criteria.fields } }

    specify { subject.only!(:field1, :field2).criteria.fields.should =~ ['field1', 'field2'] }
    specify { subject.only!([:field1, :field2]).only!(:field3).criteria.fields.should =~ ['field3'] }
    specify { subject.only([:field1, :field2]).only!(:field3).criteria.fields.should =~ ['field3'] }
  end

  describe '#types' do
    specify { subject.types(:product).should be_a described_class }
    specify { subject.types(:product).should_not == subject }
    specify { expect { subject.types(:product) }.not_to change { subject.criteria.types } }

    specify { subject.types(:user).criteria.types.should == ['user'] }
    specify { subject.types(:product, :city).criteria.types.should =~ ['product', 'city'] }
    specify { subject.types([:product, :city]).types(:country).criteria.types.should =~ ['product', 'city', 'country'] }
  end

  describe '#types!' do
    specify { subject.types!(:product).should be_a described_class }
    specify { subject.types!(:product).should_not == subject }
    specify { expect { subject.types!(:product) }.not_to change { subject.criteria.types } }

    specify { subject.types!(:user).criteria.types.should == ['user'] }
    specify { subject.types!(:product, :city).criteria.types.should =~ ['product', 'city'] }
    specify { subject.types!([:product, :city]).types!(:country).criteria.types.should =~ ['country'] }
    specify { subject.types([:product, :city]).types!(:country).criteria.types.should =~ ['country'] }
  end

  describe '#aggregations' do
    specify { subject.aggregations(attribute: {terms: {field: 'attribute'}}).should be_a described_class }
    specify { subject.aggregations(attribute: {terms: {field: 'attribute'}}).should_not == subject }
    specify { subject.aggregations(attribute: {terms: {field: 'attribute'}}).criteria.request_body[:body].should include(aggregations: {attribute: {terms: {field: 'attribute'}}}) }
  end

  describe '#merge' do
    let(:query) { described_class.new(ProductsIndex) }

    specify { subject.filter { name == 'name' }.merge(query.filter { age == 42 }).criteria.filters
      .should == [{term: {'name' => 'name'}}, {term: {'age' => 42}}] }
  end

  describe '#to_a' do
    before { stub_model(:city) }
    let(:cities) { 3.times.map { |i| City.create! name: "name#{i}", rating: i } }

    context do
      before do
        stub_index(:cities) do
          define_type :city do
            field :name
            field :rating, type: 'integer'
            field :nested, type: 'object', value: ->{ {name: name} }
          end
        end
      end

      before { CitiesIndex::City.import! cities }

      specify { CitiesIndex.order(:rating).first.should be_a CitiesIndex::City }
      specify { CitiesIndex.order(:rating).first.name.should == 'name0' }
      specify { CitiesIndex.order(:rating).first.rating.should == 0 }
      specify { CitiesIndex.order(:rating).first.nested.should == {'name' => 'name0'} }
      specify { CitiesIndex.order(:rating).first.id.should == cities.first.id.to_s }

      specify { CitiesIndex.order(:rating).only(:name).first.name.should == 'name0' }
      specify { CitiesIndex.order(:rating).only(:name).first.rating.should be_nil }
      specify { CitiesIndex.order(:rating).only(:nested).first.nested.should == {'name' => 'name0'} }

      specify { CitiesIndex.order(:rating).first._score.should be_nil }
      specify { CitiesIndex.all.first._score.should be > 0 }
      specify { CitiesIndex.query(match: {name: 'name0'}).first._score.should be > 0 }

      specify { CitiesIndex.order(:rating).first._data['_explanation'].should be_nil }
      specify { CitiesIndex.order(:rating).explain.first._data['_explanation'].should be_present }
    end

    context 'sourceless' do
      before do
        stub_index(:cities) do
          define_type :city do
            root _source: {enabled: false} do
              field :name
              field :rating, type: 'integer'
              field :nested, type: 'object', value: ->{ {name: name} }
            end
          end
        end
      end
      before { CitiesIndex::City.import! cities }

      specify { CitiesIndex.order(:rating).first.should be_a CitiesIndex::City }
      specify { CitiesIndex.order(:rating).first.name.should be_nil }
      specify { CitiesIndex.order(:rating).first.rating.should be_nil }
      specify { CitiesIndex.order(:rating).first.nested.should be_nil }
    end
  end
end
