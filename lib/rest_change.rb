module RestChange

  ############### DATABASE ####################

# Changes the working-database to {name}

  def change_database name
    @classes = []
    @database = name
  end

  ############# OBJECTS #################

=begin
  update_documents classname, set: {:symbol => 'TWR'}, where: {con_id: 340}
  Replaces the symbol to TWR in each record where the con_id is 340
  Both set and where take multiple attributes
  Returns the JSON-Response.
=end

  def update_records o_class, set:, where: {}
    url = "UPDATE #{classname(o_class)} SET #{generate_sql_list(set)} #{compose_where(where)}"


    response = @res[URI.encode("/command/#{@database}/sql/" << url)].post ''
  end
  alias update_documents update_records

# Lazy Updating of the given Record.

  def patch_record rid
    logger.progname = 'RestChange#PatchRecord'
    content = yield
    if content.is_a? Hash
      begin
        @res["/document/#{@database}/#{rid}"].patch content.to_orient.to_json
      rescue Exception => e
        logger.error{e.message}
      end
    else
  	  logger.error{"FAILED: The Block must provide an Hash with properties to be updated"}
    end
  end
  alias patch_document patch_record


  #### EXPERIMENTAL ##########

=begin
  Used to add restriction or other properties to the Property of a Class.
  See http://orientdb.com/docs/2.1/SQL-Alter-Property.html
=end

  def alter_property o_class, property:, attribute: "DEFAULT", alteration:
    logger.progname = 'RestChange#AlterProperty'
    begin
      attribute.to_s! unless attribute.is_a? String
      attribute.upcase!
      case attribute
      when "LINKEDCLASS", "LINKEDTYPE", "NAME", "REGEX", "TYPE", "REGEX", "COLLATE", "CUSTOM"
        unless alteration.is_a? String
          logger.error{"#{alteration} should be a String."}
          return 0
        end
      when "MIN", "MAX"
        unless alteration.is_a? Integer
          logger.error{"#{alteration} should be an Integer."}
          return 0
        end
      when "MANDATORY", "NOTNULL", "READONLY"
        unless alteration.is_a? Boolean
          logger.error{"#{alteration} should be an Integer."}
          return 0
        end
      when "DEFAULT"
      else
        logger.error{"Wrong attribute."}
        return 0
      end

      name_class = classname(o_class)
      execute name_class, transaction: false do # To execute commands
        [{ type: "cmd",
          language: 'sql',
          command: "ALTER PROPERTY #{name_class}.#{property} #{attribute} #{alteration}"}]
      end
    rescue Exception => e
      logger.error{e.message}
    end
  end


end
