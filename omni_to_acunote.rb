#!/usr/bin/env ruby
require 'date.rb'
require 'rubygems'
require 'nokogiri'  #gem install nokogiri
require 'xmlsimple'

puts "Missing file name to translate to omni plan, usage ./omni_to_acunote.rb file_name " unless ARGV[1] 

#Set debug mode by default false unless passed in
#DEBUG = ARGV[2] && ARGV[2] ~= /t|d/

#For now always debug
DEBUG = true


file_location = ARGV[1] || '/Users/bfeigin/Documents/Enova/Team/Q3_2011_bfeigin_team.oplx/Actual.xml'

module AcuplanTranslator

  def process_omniplan_value(key, val)
    case key
    when 'ID'
      omni_to_acunote_level_conversion(val)
    when 'Task' 
      val
    when 'End'
      Date.parse(val)
    when 'Effort'
      val.to_i
    when 'Completed'
      parse_percent(val) * @current_row['Effort'].to_f
    when 'Issue'
      val.to_i
    when 'Assigned'
      val.split.first
    when 'Priority'
      omni_to_acunote_priority(val)
    when 'Task Type'
      val =~ /Group/
    else
      val
    end
  end

  def acunote_to_omni_priority(acu_value)
    return '' if acu_value.empty?
    6 - (acu_value.gsub(/\D/,'').to_i)
  end

  def omni_to_acunote_priority(omni_value)
    'P' + (6 - (omni_value % 6)).to_s
  end

  def omni_to_acunote_level_conversion(val)
    val.count('.') + 1
  end

  def parse_percent(value)
      value.to_f / 100.0
  end
end


class OmniTask
  include AcuplanTranslator
  attr_accessor :children, :id, :attributes, :child_refs, :raw_data
  
  def initialize(raw_data)
    @raw_data = raw_data
    @attributes['type']  = raw_data['type'] || 'task'
    @attributes['title'] = raw_data['title']
    @child_refs = raw_data['child-task'].map{|node| node['idref']}
   
    #raw effort is reported in seconds we want hours
    @effort = raw_data['effort'].to_i/3600
    process_user_data(raw_data['user-data'])
  end

  def process_user_data(values)
    
  end

end

class OmniTaskGroup
  attr_accessor :roots, :doc, :resources

  # raw_file in is typically from a IO.read('file_name')
  def initialize(raw_file)
    @doc = XmlSimple.xml_in(raw_file)
    @roots     = []
    @resources = []
  
    process_resources
    process_tasks

    # We don't actually need to store the top task but do need it's children
    top_task_id = @doc['top-task'].first['idref']

    top_task = find_tasks('id', top_task_id).first
    root_tasks_raw = find_tasks('id', child_refs(top_task))
    root_tasks_raw.each do |root_task_raw|
       task = OmniTask.new(root_task_raw)
       recurse_children(task)
       @roots << task
    end
  end


  def recurse_children(task)
    task.children = find_tasks('id',child_refs(task)).map{|raw| OmniTask.new(raw)}
    task.children.each do |sub_task|
      recurse_children(sub_task)
    end
  end


  def child_refs(node)
    if node.is_a?(Hash)
      node['child-task'].map{|child| child['idref']}
    else
      node.child_refs 
    end
  end

  def find_tasks(key, value)
    if value.is_a?(Array)
      tasks.select{|task| value.include?(task[key])}
    else
      tasks.select{|task| task[key] == value}
    end
  end

  def tasks
    @tasks ||= @doc['task']
  end
  private :tasks

end


=begin
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



########################## OMNI TO ACUNOTE ############################
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

##################### END CONVERSION STRAT ################

=end
