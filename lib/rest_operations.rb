module RestOperations

# Execute a predefined Function

  def call_function *args
  #     puts "uri:#{function_uri { args.join('/') } }"
    begin
      term = args.join('/')
      @res["/function/#{@database}/#{term}"].post ''
    rescue RestClient::InternalServerError => e
  	  puts  JSON.parse(e.http_body)
    end
  end

# Used to count the Records in relation of the arguments

  def count_records **args
    logger.progname = 'RestOperations#CountRecords'
    query = OrientSupport::OrientQuery.new args
  	query.projection << 'COUNT (*)'
  	result = get_records raw: true, query: query
    begin
      result.first['COUNT']
    rescue
      return 0
    end
  end
  alias count_documents count_records
  alias count count_records

=begin
  Executes a list of commands and returns the result-array (if present)
  structure of the provided block:
  [{type: "cmd", language: "sql",  command: "create class Person extends V"}, (...)]

  It was first used by ActiveOrient::Query.execute_queries
  Later I (topofocus) discovered that some Queries are not interpretated correctly by #GetRecords but are submitted without Error via batch-processing.
  For instance, this valid query
   select expand(first_list[5].second_list[9]) from base where label = 9
  can only be submitted via batch
=end

  def execute classname = 'Myquery', transaction: true # Set up for classes
    batch = {transaction: transaction, operations: yield}
    #print "\n\n ----> #{batch.to_json} <----\n\n"
    unless batch[:operations].blank?
      begin
        response = @res["/batch/#{@database}"].post batch.to_json
      rescue RestClient::InternalServerError => e
        logger.progname = 'RestOperations#Execute'
        logger.error{e.inspect}
      end
      if response.code == 200
        if response.body['result'].present?
          result= JSON.parse(response.body)['result']
          result.map do |x|
            if x.is_a? Hash
              if x.has_key?('@class')
                ActiveOrient::Model.orientdb_class(name: x['@class']).new x
              elsif x.has_key?('value')
                x['value']
              else
                ActiveOrient::Model.orientdb_class(name: classname).new x
              end
            end
          end.compact # return_value
        else
          response.body
        end
      else
        nil
      end
    end
  end

end
