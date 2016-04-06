require 'spec_helper'

describe OrientSupport::OrientQuery do
  before( :all ) do
    ######################################## ADJUST user+password ###################
    ActiveOrient::OrientDB.default_server= { user: 'root', password: 'tretretre' }
    @r = ActiveOrient::OrientDB.new database: 'ArrayTest'
    TestQuery = @r.open_class "model_query"
    @record = TestQuery.create
  end # before

  context "Initialize the QueryClass" do
    it "simple Initialisation" do
      q =  OrientSupport::OrientQuery.new from: TestQuery
      expect(q).to be_a OrientSupport::OrientQuery
    end

    it "Initialize a traverse query" do
      q =  OrientSupport::OrientQuery.new from: TestQuery, where:{ a: 2 , c: 'ufz' }, kind: 'traverse'
      expect(q.to_s).to eq "traverse  from ModelQuery where a = 2 and c = 'ufz' "
    end

    it "Initialisation with a Parameter" do
      q =  OrientSupport::OrientQuery.new from: TestQuery, where:{ a: 2 , c: 'ufz' }
      expect(q.where_s).to eq "where a = 2 and c = 'ufz'"
      q =  OrientSupport::OrientQuery.new from: TestQuery, where:[{ a: 2} , 'b > 3',{ c: 'ufz' }]
      expect(q.where_s).to eq "where a = 2 and b > 3 and c = 'ufz'"
      q =  OrientSupport::OrientQuery.new from: TestQuery, distinct: 'name'
      expect(q.compose).to eq "select distinct( name ) from ModelQuery  "
      q =  OrientSupport::OrientQuery.new from: TestQuery, order: {name: :asc}, skip: 30
      expect( q.compose ).to eq "select  from ModelQuery  order by name asc skip 30"
      expect(q.order_s).to eq "order by name asc"
      q =  OrientSupport::OrientQuery.new from: TestQuery, projection: { "eval( 'amount * 120 / 100 - discount' )"=> 'finalPrice' }
      expect(q.projection_s).to eq "eval( 'amount * 120 / 100 - discount' ) as finalPrice"
      expect( q.compose ).to eq  "select eval( 'amount * 120 / 100 - discount' ) as finalPrice from ModelQuery  "


    end

    it "usage of limit" do
      q =  OrientSupport::OrientQuery.new  from: TestQuery
      expect(q.compose).to eq 'select  from ModelQuery  '
      expect( q.get_limit).to eq -1

      q =  OrientSupport::OrientQuery.new  from: TestQuery, limit: 23
      expect(q.to_s).to eq 'select  from ModelQuery   limit by  23'
      expect(q.compose( destination: :rest )).to eq 'select  from ModelQuery  '
      expect( q.get_limit).to eq 23

      q.limit = 15
      expect( q.get_limit).to eq 15


    end
    it "subsequent Initialisation"  do
      q =  OrientSupport::OrientQuery.new
      q.from = 'ModelQuery'
      expect( q.where << { a: 2} ).to eq [ { :a => 2 } ]
      q.where << 'b > 3'
      q.where << { c: 'ufz' }
      expect(q.where_s).to eq "where a = 2 and b > 3 and c = 'ufz'"
      q.distinct = 'name'
      q.order<< { name: :asc }
      q.order<< { vorname: :asc }
      expect(q.order_s).to eq "order by name asc, vorname asc"
      q.projection << { "eval( 'amount * 120 / 100 - discount' )"=> 'finalPrice' }
      expect(q.projection_s).to eq "distinct( name ), eval( 'amount * 120 / 100 - discount' ) as finalPrice"
      expect(q.compose). to eq "select distinct( name ), eval( 'amount * 120 / 100 - discount' ) as finalPrice from ModelQuery where a = 2 and b > 3 and c = 'ufz' order by name asc, vorname asc"
    end


    context "use the let block "  do
      it "prefetch a link-query " do
        q =  OrientSupport::OrientQuery.new from: 'ModelQuery'
        q.let << "$city = adress.city"
        q.where = "$city.country.name = 'Italy' OR $city.country.name = 'France'"

        expect( q.compose ).to eq "select  from ModelQuery let $city = adress.city where $city.country.name = 'Italy' OR $city.country.name = 'France' "

      end
      it "subqurey and expand" do
        oi_query =  OrientSupport::OrientQuery.new from: 'Openinterest', limit: 10, projection: 'expand( contracts )'
        contracts_query = OrientSupport::OrientQuery.new from: oi_query, projection: 'expand( distinct(@rid) )'
        expect( contracts_query.to_s ).to eq 'select expand( distinct(@rid) ) from  ( select expand( contracts ) from Openinterest   limit by  10 )   '
        expect( contracts_query.to_s ).to eq 'select expand( distinct(@rid) ) from  ( select expand( contracts ) from Openinterest   limit by  10 )   '

      end
      it "subquery and subsequent unionall" do

        q =  OrientSupport::OrientQuery.new
        q.let << { a:  OrientSupport::OrientQuery.new( from: '#5:0' ) }
        q.let << { b:  OrientSupport::OrientQuery.new( from: '#5:1' ) }
        q.let << '$c= UNIONALL($a,$b) '
        q.projection << 'expand( $c )'
        expect( q.to_s ).to eq 'select expand( $c ) let $a = ( select  from #5:0   ), $b = ( select  from #5:1   ), $c= UNIONALL($a,$b)   '
      end
      it "Use a subquery" do
        q =  OrientSupport::OrientQuery.new from: TestQuery, where:{ a: 2 , c: 'ufz' }
        r =  OrientSupport::OrientQuery.new from: q , kind: 'traverse', projection: :day
        expect( r.to_s ).to eq "traverse day from  ( select  from ModelQuery where a = 2 and c = 'ufz'  )   "
        s = OrientSupport::OrientQuery.new from: r, projection: 'unionall( logs ) AS logs '
        t = OrientSupport::OrientQuery.new from: s, projection: 'expand( logs ) '
        expect( t.to_s ).to eq "select expand( logs )  from  ( select unionall( logs ) AS logs  from  ( traverse day from  ( select  from ModelQuery where a = 2 and c = 'ufz'  )    )    )   "

      end
    end
  end
end  # describe
