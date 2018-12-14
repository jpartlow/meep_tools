#! /opt/puppetlabs/puppet/bin/ruby

# NOTE: You will have to install the pg gem, which is a native C lib that needs
# pe-postgresql-devel installed and the following gem install (assuming postgresql
# directories remain the same as noted here):
#
# /opt/puppetlabs/puppet/bin/gem install pg -- --with-pg-config=/opt/puppetlabs/server/apps/postgresql/bin/pg_config --with-pg-lib=/opt/puppetlabs/server/apps/postgresql/lib

require 'pg'

class Executor
  attr_accessor :dbname

  def initialize(dbname)
    self.dbname = dbname
  end

  def conn
    unless @conn
      @conn = PG.connect( dbname: dbname, user: 'pe-postgres')
    end
    @conn
  end
  
  def query(sql, &block)
    conn.exec( sql ) do |result|
      yield result
    end
  end

  def query_rows(sql, &block)
    query(sql) do |result|
      result.each do |row|
        yield row
      end
    end
  end
end

class PglogicalReport
  DTVS_PGLOGICAL = <<-EOS
        SELECT n.nspname as schema,
          c.relname as name,
          CASE c.relkind WHEN 'r' THEN 'table' WHEN 'v' THEN 'view' WHEN 'm' THEN 'materialized view' WHEN 'i' THEN 'index' WHEN 'S' THEN 'sequence' WHEN 's' THEN 'special' WHEN 'f' THEN 'foreign table' END as type,
          pg_catalog.pg_get_userbyid(c.relowner) as owner
        FROM pg_catalog.pg_class c
             LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE 
              c.relkind != 'i'
              AND n.nspname <> 'pg_catalog'
              AND n.nspname <> 'information_schema'
              AND n.nspname ~ '^(pglogical)$'
        ORDER BY 1,3,2;
  EOS

  DF_PGLOGICAL = <<-EOS
        SELECT n.nspname as schema,
          p.proname as name,
          pg_catalog.pg_get_function_result(p.oid) as result_data_type,
          pg_catalog.pg_get_function_arguments(p.oid) as argument_data_types,
         CASE
          WHEN p.proisagg THEN 'agg'
          WHEN p.proiswindow THEN 'window'
          WHEN p.prorettype = 'pg_catalog.trigger'::pg_catalog.regtype THEN 'trigger'
          ELSE 'normal'
         END as type
        FROM pg_catalog.pg_proc p
             LEFT JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname ~ '^(pglogical)$'
        ORDER BY 1, 2, 3;
  EOS

  TRIGGERS = <<-EOS
    select 
      n.nspname,
      u.usename as owner,
      c.relname,
      tgrelid,
      tgname,
      p.proname
    from
      pg_trigger t 
        left outer join pg_class c on t.tgrelid = c.oid
        left outer join pg_proc p on t.tgfoid = p.oid
        left outer join pg_namespace n on n.oid = c.relnamespace
        left outer join pg_user u on n.nspowner = u.usesysid
    where
      n.nspname ~ 'pglogical'
    order by c.relname, p.proname;
  EOS

  attr_accessor :dbname, :executor

  def initialize(dbname)
    self.dbname = dbname
    @table_list = []
    @view_list  = []
    self.executor = Executor.new(dbname)
  end
 
  def header(h) 
    puts
    puts '-' * (h.size + dbname.size + 3)
    puts "#{h} (#{dbname})"
  end

  def print_tables_and_views
    header 'Tables and Views'
    executor.query(DTVS_PGLOGICAL) do |result|
      formatted_query(result, ['Schema', 'Name', 'Type', 'Owner'])
    end
  end
 
  def print_functions 
    header 'Functions'
    executor.query(DF_PGLOGICAL) do |result|
      formatted_query(result, ['Schema', 'Name', 'result_data_type', 'Type'])
    end
    
    header 'Function Arguments'
    executor.query(DF_PGLOGICAL) do |result|
      formatted_query(result, ['Name', 'argument_data_types'])
    end
  end

  def print_triggers
    header 'Triggers'
    executor.query(TRIGGERS) do |result|
      formatted_query(result, result.fields)
    end
  end

  def formatted_query(result, fields)
    lowercased_fields = fields.map { |f| f.downcase }

    field_formats = lowercased_fields.map do |f|
      ftype = case result.ftype(result.fnumber(f))
      when 26 then 'd'
      else 's'
      end 
      fsize = result.field_values(f).reduce(0) do |size,v|
        value_size = v.to_s.length
        value_size > size ? value_size : size
      end
      fsize = fsize < f.size ? f.size : fsize
    
      [ ftype, fsize ]
    end
    
    header_format = field_formats.map do |fm|
      "%-#{fm[1]}s"
    end.join(' | ') 
    fields_format = field_formats.map do |fm|
      type, size = fm
      "%-#{size}#{type}"
    end.join(' | ')
   
    puts 
    puts header_format % fields  
    puts field_formats.map { |fm| '-' * fm[1] }.join('-+-')
    result.each do |row|
      puts fields_format % row.values_at(*lowercased_fields)
    end
    puts "(#{result.count} rows)"
  end

  def table_list 
    _init_table_view_lists
    @table_list
  end

  def view_list
    _init_table_view_lists
    @view_list
  end

  def _init_table_view_lists
    if @table_list.empty?
      executor.query_rows(DTVS_PGLOGICAL) do |row|
        case row['type']
        when 'table'
          @table_list << "#{row['schema']}.#{row['name']}"
        when 'view'
          @view_list << "#{row['schema']}.#{row['name']}"
        end
      end
    end
  end

  def print_table_data 
    header 'Table Data'
    table_list.each do |t|
      header t
      executor.query("select * from #{t}") do |result|
        formatted_query(result, result.fields)
      end
    end
  end

  def print_view_data
    header 'View Data'
    view_list.each do |v|
      header v
      executor.query("select * from #{v}") do |result|
        formatted_query(result, result.fields)
      end
    end
  end

  def print_report
    puts "==========================================="
    header "Database: #{dbname}"
    print_tables_and_views
    print_functions
    print_triggers
    print_table_data
    print_view_data
    puts
  end
end

databases = [
  'pe-activity',
  'pe-classifier',
  'pe-orchestrator',
  'pe-rbac',
]

databases.each do |d|
  reporter = PglogicalReport.new(d)
  reporter.print_report
end
