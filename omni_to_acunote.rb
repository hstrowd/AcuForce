#!/usr/bin/env ruby
require 'date.rb'
require 'rubygems'
require 'nokogiri'  #gem install nokogiri
require 'fastercsv' #gem install fastercsv

puts "Missing file name to translate to omni plan, usage ./omni_to_acunote.rb file_name " unless ARGV[1] 

#Set debug mode by default false unless passed in
#DEBUG = ARGV[2] && ARGV[2] ~= /t|d/

#For now always debug
DEBUG = true

@omni_in = nil
@omni_headers = nil
@omni_tasks = nil

@file_location = ARGV[1] || '/Users/bfeigin/Documents/Enova/export_v2/Q3_2011_bfeigin_team.html'

def omni_file_to_tasks(file_location = @file_location, force = false)
  puts "opening file #{@file_location}" if DEBUG
  
  if force
    puts "clearing file and variables by force" if DEBUG
    @omni_headers = @omni_tasks = @omni_in = nil
  end

  return @omni_tasks if @omni_tasks

  # Set up the file to parse
  # First grab headers then to get the tasks
  # For each node (excluding the project title header [0]) find the XML Elements 
  # and then grab the text inside of each of those
  @omni_in      = Nokogiri::HTML(open(file_location))
  @omni_headers = @omni_in.css('.header').map{|x| x.children.first.text}
  @omni_tasks   = @omni_in.css('.task_anchor')[1..-1].map do |task_node|
    task_node.children.select{ |noko_nodes| Nokogiri::XML::Element === noko_nodes }.map{ |data|
      data.children.first && data.children.first.text }
  end
end


#Convienence method creates an array of omni_header => omni_value
def map_row_to_headers(rows = @omni_tasks, headers = @omni_headers)
  return {} unless (rows && headers)
  
  row_array = []
  rows.each do |row| 
    row_hash = Hash.new
    headers.each_with_index do |header, index|
      row_hash[header] = row[index]
    end
    row_array << row_hash
  end
  row_array
end

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



ID, Level,  omni_to_acunote_level_conversion(val)
#Task, Description, val
#End, Due Date, Date.parse(val)
#Effort, Estimate, val.to_i #omni_to_acu_time(val)
#Completed, Remaining, parse_percent(val) * Estimate.to_f
#Issue, Number, val.to_i
#Assigned, Owner, val.split.first
#Priority, Priority, omni_to_acunote_priority(val)
#Task Type, Is Group, val ~= /Group/


#META DATA ONLY
Start
Duration
Task Cost
Planned Start
Planned End
Notes


def omni_to_acunote_level_conversion(val)
  val.count('.') + 1
end


def omni_to_acu_time(time_as_string)
  
  return time.to_i

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
