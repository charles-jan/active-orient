
require 'spec_helper'
require 'active_support'

module ActiveOrient
  class Base
    def self.get_riid
      @@rid_store
    end
  end
end

describe ActiveOrient::Model do
  before( :all ) do

    ActiveOrient::OrientDB.logger =  ActiveOrient::Model.logger = Logger.new('/dev/stdout')
    ActiveOrient::OrientDB.default_server= { user: 'root', password: 'tretretre' }
    ActiveOrient::Base.logger = Logger.new('/dev/stdout')

    @r= ActiveOrient::OrientDB.new database: 'MyTest'
    @r.delete_class 'model_test'
    TestModel = @r.open_class "model_test"
    @myedge = @r.create_edge_class  'Myedge'
    @mynode = @r.create_vertex_class  'Mynode'
  end

  context "ActiveOrient::Model classes got a logger and a database-reference" do

    subject { ActiveOrient::Model.orientdb_class name: 'Test' }
    it{ is_expected.to be_a Class }
    its( :logger) { is_expected.to be_a Logger }
    its( :orientdb) { is_expected.to be_a ActiveOrient::OrientDB }

    it "a Model-Instance inherents logger and db-reference" do
      object =  subject.new
      expect( object.logger ).to be_a Logger
      expect( object.orientdb ).to be_a ActiveOrient::OrientDB
    end

    it "repeatedly instantiated Model-Objects are allocated once" do
      second =  ActiveOrient::Model.orientdb_class name: 'Test'
      expect( second).to eq subject
    end
  end

  context "The Models have proper superClasses"  do
    it "A document class has an empty superClass" do
      expect( TestModel.superClass ).to eq ""
    end
    it "An Vertex inherents from »V«" do
      expect( @mynode.superClass ).to eq "V"
    end
    it "An Edge inherents from »E«" do
      expect( @myedge.superClass ).to eq "E"
    end
  end


  context "add properties and indexes" do
    it "create a single property" do
      @r.delete_class 'index_test'
      TestIndex = @r.open_class "index_test"
      TestIndex.create_property( :test, type: 'string' ){ :unique }
      expect( TestIndex.get_properties[:properties] ).to have(1).item
      expect( TestIndex.get_properties[:indexes] ).to have(1).item
    end
    it "create a single property with a manual index" do
      @r.delete_class 'index_test'
      TestIndex = @r.open_class "index_test"
      TestIndex.create_property( :test, type: 'string', index: {test_ind: :unique} )
      expect( TestIndex.get_properties[:properties] ).to have(1).item
      expect( TestIndex.get_properties[:indexes] ).to have(1).item
    end
    it "create several  properties with a composite index" do
      @r.open_class :industry
      @r.delete_class 'index_test'
      TestIndex = @r.open_class "index_test"
      count= TestIndex.create_properties(	 test:  {type: :integer},
      symbol: { type: :string },
      industries: { type: 'LINKMAP', linked_class: 'Industry' }   ) do
        { test_ind: :unique }
      end
      expect( TestIndex.get_properties[:properties] ).to have(3).items
      expect( TestIndex.get_properties[:indexes] ).to have(1).item
    end

    it "put some data into the class" do

      (0..45).each{|x| TestIndex.create  test: x  }
      expect( TestIndex.count ).to eq 46
    end
  end

  context "Add a document to the class"  do
    it "the database is empty before we start" do
      expect( @r.get_documents  from: TestModel ).to be_empty
      expect( TestModel.count ).to be_zero
    end

    let( :new_document ){ActiveOrient::Model::ModelTest.create test: 45 }
    it "create a document"  do
      expect( new_document.test ).to eq 45
      expect(new_document).to be_a ActiveOrient::Model::ModelTest
      expect( ActiveOrient::Base.get_riid.values.detect{|x| x == new_document}).to be_truthy
    end


    it "the document can be retrieved by all"  do
      all = TestModel.all
      expect(all).to be_a Array
      expect(all.size).to eq 1
      expect(all.first).to  be_a ActiveOrient::Model::ModelTest
      expect(all.first.test).to eq 45
    end

    it "the document can be retrieved by first" do
      expect( TestModel.first ).to be_a ActiveOrient::Model::ModelTest
      expect( TestModel.first.test ).to eq 45
    end

    it "the document can be updated"  do
      obj =  TestModel.create test: 77
      expect{ obj.update set: { test: 76, new_entry: "This is a new Entry" } }.to change{ obj.version }.by 1
      expect( obj.test ).to eq 76
      expect( obj.new_entry).to be_a String
    end

    it "various Properties can be added to the document" do
      obj =  TestModel.first
      obj.update set: { a_array: aa= [ 1,4,'r', :r ]  , a_hash: { :a => 'b', b: 2 } }
      expect( obj.a_array ).to eq aa
      expect{ obj.reload! }.not_to change{ obj.attributes }
    end

    it "a value can be added to the array" do
      obj =  TestModel.first
      obj.add_item_to_property 'a_array', 56
      expect(obj.a_array).to eq [ 1,4,'r', 'r', 56 ]

    end

    it "the document can be deleted"  do
      obj =  TestModel.first
      expect{ obj.delete }.to change { TestModel.count }.by -1
    end
  end

  context "ActiveRecord mimics"    do
    before(:all){ (0..45).each{|x| TestModel.create  test: x  }}
    it "fetch all documents into an Array" do
      all_documents = TestModel.all
      expect( all_documents ).to be_a Array #HashWithIndifferentAccess
      expect( all_documents ).to have_at_least(46).elements
      all_documents.each{|x| expect(x).to be_a ActiveOrient::Model }
    end

    it "get a set of documents queried by where"  do
      all_documents = TestModel.all  ## all fetches only 20 records
      nr_23=  TestModel.where  test: 23
      expect( nr_23 ).to have(1).element
      expect( nr_23.first.test).to eq 23
      expect( TestModel.all.size).to eq  47
    end
    it "datasets are unique only  on update" do
      expect{ TestModel.update_or_create(  :where => { test: 45 }) }. not_to change { TestModel.count }
      expect{ TestModel.create  test: 45 }.to change { TestModel.count }
    end


    it "creates an edge between two documents"  do
      node_1 =  @r.update_or_create_documents(  @mynode, :where => { test: 23 } ).first
      node_2  =  @r.update_or_create_documents( @mynode, :where => { test: 15 } ).first
      node_3 = @r.update_or_create_documents(  @mynode, :where => { test: 16 } ).first
      the_edge= @myedge.create_edge(
      attributes: { halbwertzeit: 45 },
      from: node_1,
      to:   node_2  )
      expect( the_edge).to be_a ActiveOrient::Model

      # creation of a second edge with the same properties leads to  reusing the existent edge
      the_edge2= @myedge.create_edge(
      attributes: { halbwertzeit: 45 },
      from: node_1,
      to:   node_2 , unique: true )
      expect( the_edge.link ).to eq the_edge.link
      #      the_edge2= @myedge.create_edge(
      #			  attributes: { halbwertzeit: 46 },
      #			  from: in_e,
      #			  to:   in_e2  )
      expect( the_edge.out ).to eq node_1.link
      expect( the_edge.in ).to eq node_2.link
      #      expect( the_edge2.out ).to eq in_e
      #      expect( the_edge2.in ).to eq in_e2
      out_e =  @mynode.where(  test: 23  ).first
      expect( out_e ).to eq node_1.link
      expect( out_e.attributes).to include 'out_Myedge'
      in_e = @mynode.where(  test: 15  ).first
      #      puts "--------------------------------"
      #      puts node_1.attributes.inspect
      #      expect( in_e.attributes).to include 'in_Myedge'
      #    expect( node_1.myedge).to have(1).item
      #    expect( node_1.myedge[0][:out].test).to eq 23
      #    expect( node_1.in_Myedge[0][:in].test).to eq  15
    end

    it "deletes an edge"  do
      the_edges =  @myedge.all
      expect(the_edges.size).to  be >=1

      the_edges.each do |edge|
        edge.delete
      end
      the_edges =  @myedge.all
      expect(the_edges.size).to  be_zero
    end

  end


end
