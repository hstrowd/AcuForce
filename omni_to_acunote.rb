#!/usr/bin/env ruby
require 'date.rb'
require 'rubygems'
require 'nokogiri'  #gem install nokogiri
require 'xmlsimple'
require '~/code/AcuPlan/AcuPlan.rb'

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
    return '' unless omni_value
    'P' + (6 - (omni_value.to_i % 6)).to_s
  end

  def parse_percent(value)
      value.to_f / 100.0
  end
end


class OmniTask
  include AcuplanTranslator

  attr_accessor :children, :issue_number, :attributes, :child_refs, :raw_data
  attr_accessor :title, :task_type, :task_level, :prerequisites, :owner_ref, :owner_name, :meta_data,
                :effort, :effort_done
  
  def initialize(raw_data, level, owner_name = nil)
    #Keep a copy of the raw data we generated the task from
    @raw_data = raw_data
   
    #Holder for any overflow info
    @meta_data = {}

    @task_level = level
    @title = raw_data['title'].first
    @task_type  = raw_data['type'] || 'task'
    @prerequisites = raw_data['prerequisite-task']
    @child_refs = (raw_data['child-task'] || []).map{|node| node['idref']}
    @owner_ref = raw_data['assignment'] && raw_data['assignment'].first['idref']
    @effort_required = (raw_data['effort'] && raw_data['effort'].first && raw_data['effort'].first.to_i/3600) 
    @priority = raw_data['priority'] && raw_data['priority'].first
    @effort_done= (raw_data['effort_done'] && raw_data['effort_done'].first && raw_data['effort_done'].first.to_i/3600) 

    if level > 4
      puts "Acunote does not currently support more then 4 levels deep"
      puts "Task #{@title} is at level #{level}, and needs to be special cased"
    end

    #process_user_data

    if raw_data['user-data']
      raw_data['user-data'].each do |user_data|
        case user_data['key']
        when 'Offshore'
          @meta_data[:Offshore]   = true
        when /MX/
          @meta_data[:MXCritical] = true
        else
          #TODO PUT BACK
          @issue_number = nil #user_data['string']
        end
      end
    end
    #raw effort is reported in seconds we want hours
  end

  def remaining
    return unless @effort_required && @effort_done
    @effort_required - @effort_done
  end

  def dependents
    children.map{|x| x.issue_number}.compact.join(',')
  end

  def acunote_level
    @task_level
  end

  def omni_level
    level - 1
  end

  def to_s
    "Title: #{@title} \n children_refs: [#{@child_refs.join(", ")}] \n level #{@task_level}\n" 
  end
  
  def to_acunote_csv
     [
      acunote_level,
      issue_number, 
      title, 
      meta_data[:Tags], 
      owner_name,
      nil,
      nil,
      omni_to_acunote_priority(@priority),
      nil,
      effort,
      remaining,
      nil,nil,nil, #Due Date,QA Owner,Business Owner,
      nil,nil, #Wiki,Watchers
      nil, #Depends_on (set by dependents)
      (('"' + dependents + '"') unless dependents.empty?), #Dependents
      nil
    ].join(',')
  end
end


class OmniTaskGroup
  include AcunoteBase
  include AcunoteSprint

  attr_accessor :sprints, :doc, :resources

  # raw_file in is typically from a IO.read('file_name')
  def initialize(raw_file)
    @mech = Mechanize.new
    @doc = XmlSimple.xml_in(raw_file)
    @sprints     = []
    @resources = []

    acunote_login
    process_tasks
  end

  def process_tasks
    top_task_id = @doc['top-task'].first['idref']

    top_task = find_tasks('id', top_task_id).first
    sprint_tasks_raw = find_tasks('id', child_refs(top_task))
    sprint_tasks_raw.each do |sprint_task_raw|
       task = OmniTask.new(sprint_task_raw, 0)
       build_children(task)
       @sprints << task
    end
    true
  end

  def assign_resource_name_for_task(task)
    resource = find_resource('id',task.owner_ref)
    unless resource.empty?
      task.owner_name = resource.first['name'].first
    end
  end

  def to_s
    sprints.each do |sprint|
      sprint.to_s
    end
  end


  def push_to_acunote
    sprint_sprint_ids = @sprints.map do |sprint|
      ref = find_sprint_by_name("BFEIGIN TEST"+sprint.title) || (create_sprint("BFEIGIN TEST"+sprint.title) && find_sprint_by_name("BFEIGIN TEST"+sprint.title))
      ref.href.split('/').select{|chunk| chunk =~ /\d+/}.last
    end
  end

  def sprints_to_csv
    sprint_map = {}
    @sprints.each do |sprint|
      sprint_map[sprint.title] =  sprint.children.map do |root|
        task_to_acunote(root,[])
      end.flatten
    end
    sprint_map
  end

  # Acunote Format:
  # Level,Number,Description,Tags,Owner,Status,Resolution,Priority,Severity,Estimate,Remaining,Due Date,QA Owner,Business Owner,Wiki,Watchers,Related,Duplicate,Predecessors,Successors,Version 1
  #
  def task_to_acunote(task, to_csv)
    to_csv << task.to_acunote_csv  

    if task.children.size > 0
      to_csv << task.children.map do |child|
        task_to_acunote(child, [])
      end
    end
    to_csv.flatten
  end

  def build_children(task, level = 0)
    assign_resource_name_for_task(task)
    task.children = find_tasks('id',child_refs(task)).map{|raw| OmniTask.new(raw, level + 1)}
    task.children.each do |sub_task|
      build_children(sub_task, level + 1)
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
    val = if value.is_a?(Array)
      tasks.select{|task| value.include?(task[key])}
    else
      tasks.select{|task| task[key] == value}
    end
    val || []
  end

  def find_resource(key,value)
    resources.select{|res| res[key] == value}
  end

  def resources
    @resources ||= @doc['resource'][1..-1]
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
