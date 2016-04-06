require_relative '../lib/active-orient.rb'
require 'time'

ActiveOrient::OrientDB.default_server = {user: 'root', password: 'tretretre'}
r = ActiveOrient::OrientDB.new database: 'NewTest'
r.delete_database database: "NewTest"

def create1month
  r = ActiveOrient::OrientDB.new database: 'NewTest'

  hour_class   = r.create_vertex_class "Hour", properties: {value_string: {type: :string}, value: {type: :integer}}
  hour_class.alter_property property: "value", attribute: "MIN", alteration: 0
  hour_class.alter_property property: "value", attribute: "MAX", alteration: 23


  day_class    = r.create_vertex_class "Day", properties: {value_string: {type: :string}, value: {type: :integer}}
  day_class.alter_property property: "value", attribute: "MIN", alteration: 1
  day_class.alter_property property: "value", attribute: "MAX", alteration: 31

  month_class  = r.create_vertex_class "Month", properties: {value_string: {type: :string}, value: {type: :integer}}
  month_class.alter_property property: "value", attribute: "MIN", alteration: 1
  month_class.alter_property property: "value", attribute: "MAX", alteration: 12


  timeof_class = r.create_edge_class "TIMEOF"

  timestamp = DateTime.strptime("1456704000",'%s')
  monthVertex = month_class.create(value_string: "March", value: 3)
  for day in 1..31
    dayVertex = day_class.create(value_string: "March #{timestamp.day}", value: day)
    for hour in 0..23
      print "#{timestamp.year} #{timestamp.month} #{timestamp.day} #{timestamp.hour} \n"
      hourVertex = hour_class.create(value_string: "March #{timestamp.day} #{timestamp.hour}:00", value: hour)
      timeof_class.create_edge from: dayVertex, to: hourVertex
      timestamp += Rational(1,24)
    end
    timeof_class.create_edge from: monthVertex, to: dayVertex
  end
end

 r = ActiveOrient::OrientDB.new database: 'NewTest'

create1month

mon = r.open_class "Month"
print "1 #{mon.all} \n \n"

firstmonth = mon.first
print "2 #{firstmonth.to_human} \n \n"
print "2.5 #{firstmonth.value} \n \n"

days = firstmonth.out_TIMEOF
print "3 #{days.to_human} \n \n"

first_day = firstmonth.out_TIMEOF[0].in
print "4 #{first_day.to_human} \n \n"

thirteen_hour = firstmonth.out_TIMEOF[0].in.out_TIMEOF[12].in
print "5 #{thirteen_hour.value} \n \n"
print "6 #{thirteen_hour.to_human} \n \n"

test2 = firstmonth["out_TIMEOF"].map{|x| x["in"]}
print "7 #{test2} \n \n"

mon.add_edge_link name: "days", direction: "out", edge: "TIMEOF"
print "8 #{firstmonth.days.map{|x| x.value}} \n \n"

print "9 #{firstmonth.days.value_string} \n \n"
