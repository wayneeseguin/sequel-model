module Sequel
  class Model
    
    # Handles join tables.
    # Parameters are the first class and second class:
    #
    #   @join_table = JoinTable.new :post, :comment
    #
    # The join table class object is available via
    #
    #   @join_table.class #=> PostComment
    #
    class JoinTable
      
      attr_accessor :join_class
      attr_accessor :source
      attr_accessor :destination
      attr_accessor :options
      
      def self.keys(klass)
        singular_klass = Inflector.singularize(klass.table_name)        
        [klass.primary_key].flatten.map do |key|
          [ singular_klass, key.to_s ].join("_")
        end
      end
      
      def initialize(source, destination, options = {})
        @source      = source
        @destination = destination
        @options     = options
      end

      def source_class
        @source_class ||= Inflector.constantize(Inflector.classify(@source))
      end

      def destination_class
        @destination_class ||= Inflector.constantize(Inflector.classify(@destination))
      end

      def join_class
        # Automatically Define the JoinClass if it does not exist
        instance_eval <<-JOINCLASS
        unless defined?(::#{source_class}#{destination_class})
          @join_class = 
          class ::#{source_class}#{destination_class} < Sequel::Model
            set_primary_key [:#{(self.class.keys(source_class) + self.class.keys(destination_class)).join(", :")}]
          end
        else
          @join_class = ::#{source_class}#{destination_class}
        end
        JOINCLASS
      end
      
      # Outputs the join table name
      # which is sorted alphabetically with each table name pluralized
      # Examples:
      #   join_table(user, post) #=> :posts_users
      #   join_table(users, posts) #=> :posts_users
      def name
        [source_class.table_name.to_s, destination_class.table_name.to_s].sort.join("_")
      end
      
      def create(hash = {})
        @join_class.new(hash).save
      end
      
      # creates a join table
      def create_table
        if !exists?
          # tablename_key1, tablename_key2,...
          # TODO: Inflect!, define a method to return primary_key as an array
          instance_eval <<-JOINTABLE
          db.create_table name.to_sym do
            #{source_class.primary_key_def.reverse.join(" :#{Inflector.singularize(source_class.table_name)}_")}, :null => false
            #{destination_class.primary_key_def.reverse.join(" :#{Inflector.singularize(destination_class.table_name)}_")}, :null => false
          end
          JOINTABLE
          true
        else
          false
        end
      end
      
      # drops the the table if it exists and creates a new one
      def create_table!
        db.drop_table name if exists?
        create_table
      end
      
      # returns true if exists, false if not
      def exists?
        self.db[name.to_sym].table_exists?
      end
      
      def db
        source_class.db
      end
      
    end

  end
end
