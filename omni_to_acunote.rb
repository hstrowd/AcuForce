#!/usr/bin/env ruby
require 'date.rb'
require 'rubygems'
require 'fastercsv' #gem install fastercsv

#FasterCSV.foreach("data.csv", :quote_char => '"', :col_sep =>';', :row_sep =>:auto) do |row|
#  puts row[0]
#  break
#end
#


puts "Missing file name to translate to omni plan, usage ./omni_to_acunote.rb file_name " unless ARGV[1] 



#Set debug mode by default false unless passed in
DEBUG = ARGV[2] && ARGV[2] ~= /t|d/

#For now always debug
DEBUG = true

def read_omni_file
puts "opening file #{ARGV[1])}" if DEBUG
rows = FasterCSV.read(ARGV[1])
File.open(ARGV[1], 'r').each do |line|
  puts "line #{line}" if debug
  lines << line.chmod.split(',')
end
  
headers = lines.delete_at(0)

output 







#TODO Prereqs will require post processing, because only acunote has master "ID" number for all tasks 
# Omni -> Acunote
#   Need to create the task before you can set up a dependency so might have to be two step upload
# 
# Acu -> Omni
#   Need to be able to refence a task by Issue Number to UID mapping

####################### CONVERSION STRAT #####################

#ACUNOTE TO OMNI
Number, Issue, val
Description, Task, val
Owner, Assigned, val
Priority, Priority, acunote_to_omni_priority(val)
Estimate, Effort, val+'h'
Remaining, Completed (val.to_f/acu_data[Estimate].to_f) + '%'


def acunote_to_omni_priority(acu_value)
  return '' if acu_value.empty?
  6 - (acu_value.gsub(/\D/,'').to_i)
end

#OMNI TO ACUNOTE
#OmniPlan, Acunote, proc 

OMNI_DAY_TO_ACUNOTE_HOUR_CONVERSION_RATE = Hash.new(5) #Default everyone to 5 hours for now


WBS Number, Level,  omni_to_acunote_level_conversion(val)
Task, Description, val
End, Due Date, Date.parse(val)
Effort, Estimate, omni_to_acu_time(val)
Completed, Remaining, parse_percent(val) * Estimate.to_f
Issue, Number, val.to_i
Assigned, Owner, val.split.first
Priority, Priority, omni_to_acunote_priority(val)

#META DATA ONLY
Start
Duration
Task Cost
Planned Start
Planned End
Notes


def omni_to_acunote_level_conversion(val)
  val.count('.') + 1


def omni_to_acu_time(time_as_string)
  total_time = 0 #number of omni hours
  time_array = time_as_string.split
  time_array.each do |x|
    case x
    when /d/
      total_time += OMNI_DAY_TO_ACUNOTE_HOUR_CONVERSION_RATE[@user_name] * x.to_i
    when /h/
      total_time += x.to_i
    end
  end
end


def omni_to_acunote_priority(omni_value)
  'P' + (6 - (omni_value % 6)).to_s
end


def parse_percent(value)
    value.to_f / 100.0
end










##################### END CONVERSION STRAT ################
#
