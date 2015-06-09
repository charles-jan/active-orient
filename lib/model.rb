module REST

#require 'base'
#require 'base_properties'

class Model < REST::Base
   include BaseProperties

   mattr_accessor :orientdb
   mattr_accessor :logger

   def self.orientdb_class name: 
       #logger.progname =  "REST::Model#orientdb_class" 
     klass = Class.new( self )
     name =  name.camelize
     if self.send :const_defined?, name 
      # logger.debug { "Class  #{name} already defined ... skipping" }
       retrieved_class =  self.send :const_get, name
     else
     
	new_class = self.send :const_set  , name.capitalize , klass
	new_class.orientdb =  orientdb
	new_class # return_value
     end
   end

=begin
Returns just the name of the Class 
=end
   def classname
      self.class.to_s.split(':')[-1]
   end


   # hard-coded orientdb-columns
#     prop :cluster, :version, :record, :fieldtypes
  
#   def default_attributes
#     super.merge cluster: 0
#     super.merge version: 0
#     super.merge record: 0
#   end
=begin
rid is used in the where-part of sql-queries
=end
   def rid
     if @metadata.has_key?( 'cluster')
       "#{@metadata[ :cluster ]}:#{@metadata[ :record ]}"
     else
       "0:0"
     end
   end
=begin
link is used in any sql-commands 
eg .  update #link set  ...
=end
   def link
     "##{rid}"
   end

   def version
     @metadata[ :version ] 
   end

   ### currently not used
   def self.dynamic response_hash
     response_hash.each do | key, value |
       unless attributes.keys.include? key?
	 self.class.define_property key
       end
     end
   end
=begin 
Queries the database and fetches the count of datasets
=end
   def self.count_documents where: {}
     orientdb.count_documents( o_class: self , where: where)
   end

   def self.new_document attributes: {}
     f= orientdb.update_or_create_document o_class: self, set: attributes
     f.size == 1 ? f.first : f
   end

   def self.create_edge attributes:{}, from:, to:
      orientdb.nexus_edge o_class: self, attributes: attributes, from: from, to: to
   end

   def self.where attributes: {}
     orientdb.get_documents o_class: self,  where: attributes
   end
  
   def delete
     if is_edge?
       # returns the count of deleted edges
       orientdb.delete_edge link
     else
      r= orientdb.delete_document link
     end
   end

   def is_edge?
     attributes.keys.include?( 'in') && attributes.keys.include?('out')
   end
   def self.all
     orientdb.get_documents o_class:  self
   end
=begin
Convient update of the dataset by calling sql-patch
The attributes are saved to the database.
The optional :set argument 
=end
   def update  set: {}
      attributes.merge! set
     result= orientdb.patch_document(rid) do
       attributes.merge( { '@version' => @metadata[ :version ], '@class' => @metadata[ :class ] } )
     end
#     returns a new instance of REST::Model
     REST::Model.orientdb_class(name: classname).new  JSON.parse( result )

   end

=begin
Convient method for updating a linkset-property
its called via
  model.update_linkset(  REST::Query.new , :property, Object that provides the link )
=end
   def update_linkset q_class, item, link_class
     q_class.queries = [ "update #{link} add #{item} = #{link_class.link}" ]
     puts q_class.queries.inspect
     q_class.execute_queries

   rescue RestClient::InternalServerError => e
     puts e.inspect
     puts "update_linkset : Duplicate found (#{link_class.link})"
   end

end # class

end # module
