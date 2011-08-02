#!/usr/bin/env ruby
require 'date.rb'
require 'rubygems'
require 'nokogiri'  #gem install nokogiri
require 'xmlsimple'
require 'csv'
require 'builder'
require './AcuPlan.rb'

#For now always debug


#puts "Missing file name to translate to omni plan, usage ./omni_to_acunote.rb file_name " unless file_location

module AcuplanTranslator

  def acunote_to_omni_priority(acu_value)
    return '' if acu_value.empty?
    6 - (acu_value.gsub(/\D/,'').to_i)
  end

  #shorting for now if it's 0#shorting for now
  # TODO
  def omni_to_acunote_priority(omni_value)
    return nil if omni_value.to_i == 0 

    return '' unless omni_value
    'P' + (6 - (omni_value.to_i % 6)).to_s
  end

  def parse_percent(value)
      value.to_f / 100.0
  end

  #shorting for now 
  # TODO
  def dependents
    return nil
    children.map{|x| x.taskID}.compact.join(',')
  end
  
  def remaining
    return unless @effort_required && @effort_completed
    @effort_required - @effort_completed
  end

  def acunote_level
    @task_level
  end

end

class OmniTask
  include AcuplanTranslator

  attr_reader   :taskID
  attr_accessor :children, :child_refs, :raw_data
  attr_accessor :title, :task_type, :task_level, :prerequisites, :owner_ref, :owner_name, :meta_data,
                :effort, :effort_completed, :refID
  
  def initialize(raw_data, level, owner_name = nil)
    #Keep a copy of the raw data we generated the task from
    @raw_data = raw_data
   
    #Holder for any overflow info
    @meta_data = {}

    @task_level = level
    @title = raw_data['title'].first
    @task_type  = raw_data['type'] || 'task'
    @refID = raw_data['id']
    @prerequisites = raw_data['prerequisite-task']
    @child_refs = (raw_data['child-task'] || []).map{|node| node['idref']}
    @owner_ref = raw_data['assignment'] && raw_data['assignment'].first['idref']
    @effort_required = (raw_data['effort'] && raw_data['effort'].first && raw_data['effort'].first.to_i/3600) 
    @priority = raw_data['priority'] && raw_data['priority'].first
    @effort_completed= (raw_data['effort_done'] && raw_data['effort_done'].first && raw_data['effort_done'].first.to_i/3600) 

    if level > 4
      puts "Acunote does not currently support more then 4 levels deep"
      puts "Task #{@title} is at level #{level}, and needs to be corrected"
      exit -1
    end

    #process_user_data

    if raw_data['user-data']
      raw_data['user-data'].each do |user_data|
        if user_data['key'].first == 'TaskID'
          @taskID = user_data['string'].first
        end
      end
    end
  end


  # Checks that we don't already have a TaskID assigned
  # Builds or adds a new key value pair to the user-data section of the raw data hash
  # sets the taskID instance variable
  # sets the refID to the instance variable + 't' for omniplan compliance
  # 
  # Returns:
  #   old_refID - the previous reference ID for the task 
  #
  def add_task_id!(value)
    #Once we have a value for TaskID we don't want to be able to change it from here(for now at least)
    return false if @raw_data['user-data'] && @raw_data['user-data'].any?{|kvp| kvp['key'] == 'TaskID'}
    
    #need to create the user data field
    @raw_data['user-data'] ||= []
    @raw_data['user-data'] << {'string' => [value], 'key' => ['TaskID']}
    @taskID = value

    old_refID = @refID.to_s
    @refID = 't' + value
    @raw_data['id']= @refID

    return old_refID
  end

  def taskID
    @taskID && @taskID.gsub('t','')
  end

  # Acunote Format:
  # Level,Number,Description,Tags,Owner,Status,Resolution,Priority,Severity,
  # Estimate,Remaining,Due Date,QA Owner,Business Owner,Wiki,Watchers,Related,
  # Duplicate,Predecessors,Successors,Version 1
  #
  def to_acunote_csv
     [
      acunote_level,
      @taskID, 
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
      nil, #Dependents TODO
      nil
    ].join(',')
  end

  def to_s
    "Title: #{@title} \n children_refs: [#{@child_refs.join(", ")}] \n level #{@task_level}\n" 
  end

end


class OmniTaskGroup
  include AcunoteBase
  include AcunoteSprint

  attr_accessor :sprints, :doc, :resources, :file_path, :raw_file, :debug

  OMNI_PLAN_XML_HEAD= '<?xml version="1.0" encoding="utf-8" standalone="no"?>'

  def initialize(file_path)
    @mech = Mechanize.new

    if file_path =~ /Actual\.xml$/
      @file_path = file_path
    else
      @file_path = file_path + '/Actual.xml'
    end
    @raw_file = File.read(@file_path)
    @doc = XmlSimple.xml_in(@file_path)
    @sprints     = []
    @debug = true

    acunote_login
    process_tasks
    #save_omni_plan_file
  end

  #======= \ Acunote Modifications \  =====

  # The big cahuna
  # First make sure all top level project sprints exist in acunote
  # then for each of the sprints upload a csv of it's tasks to that sprint
  #
  # Returns: 
  #   true - each of the acunote sprints were updates correctly
  #   false - something went wrong and a sprint was not updated correctly
  # 
  def push_to_acunote!
    return false unless prepare_project_sprints!
    result = @sprints.all? do |sprint|
      upload_csv_to_sprint(sprint_to_csv(sprint), sprint.taskID)
    end
    if result
      @sprints.all? do |sprint|
        CSV.parse(export_csv_from_sprint(sprint.taskID)).each_with_index do |task_line,index|
          #Scared that i will have stale objects curse my total understanding of ruby object storage
          #I'm thinking i will have to do this though, good thing non of these are in anyway computationally hard :p
          sprint_task_list = flat_task_list(sprint)
          #Skip the header
          if index == 0
            next
          end
          sprint_task_list[index].update_task_with_id(task_line[1])
        end
      end
    end
    save_omni_plan_file(true)
  end


  # wrapper to iterate over each of the project sprints
  # Makes sure each of them either has a taskID in which case we can assume it already exists
  # OR
  # Creates a new sprint, then finds the newly created sprint, 
  # then parses the taskID out of the href for that sprint.
  #
  # Returns:
  #   true - All sprints were created or already exist
  #   false - Something went wrong
  #
  def prepare_project_sprints!
    prefix = (@debug && "BFEIGIN TEST") || 'PROJECT'
     @sprints.all? do |sprint|
      prepare_project_sprint(sprint, prefix)
    end
  end

  # If a sprint doesn't currently have a TaskID:
  # we need to build a sprint in acunote, 
  # and assosiate that taskID in the raw_file
  # if all goes well we return true
  def prepare_project_sprint(sprint, prefix)
    unless sprint.taskID
      ref = (create_sprint(prefix + sprint.title) && find_sprint_by_name(prefix + sprint.title))
      update_task_with_id(sprint,ref.href.split('/').select{|chunk| chunk =~ /\d+/}.last)
    end
    true
  end

  # Uses task_to_acunote to generate a csv of tasks for each of the sprints found during initialization
  def sprint_to_csv(sprint)
    flat_task_list(sprint, false).map{|task| task.to_acunote_csv}.join("\r\n")
  end

  #======= / Acunote Modifications /  =====


  #======= \ OmniPlan File Modifications \ =====
  #
  #"/Users/bfeigin/Documents/Enova/OmniPlanBackups/#{name}"
  #Still in test mode
  def save_omni_plan_file(use_temp_storage=false)
    if use_temp_storage
      File.open(file_path+Time.now.to_s, 'w'){|z| z.write(export_raw_file)}
    else
      File.open(file_path, 'w'){|z| z.write(export_raw_file)}
    end
  end

  #File.open('/Users/bfeigin/Documents/Enova/testing/testv2.oplx/not.xml','w'){|x| x.write('<?  xml version="1.0" encoding="utf-8" standalone="no"?>' + XmlSimple.xml_out(xml,{:RootName => 'scenario'}))}

  def export_raw_file
    OMNI_PLAN_XML_HEAD + "\n" +
      
    <  + XmlSimple.xml_out(@doc,{:RootName => 'scenario'})
  end

  # 1 - update the task in the 'doc' with task that has the user-data
  # 2 - Write the entire doc out to raw
  # 3 - update the raw with the string pattern match
  # 4 - re-read the doc back in now with the updated values
  # 5 - recreate all tasks to be safe, as these models do not have a concept of staleness
  # TODO To an orm soon enough
  def update_task_with_id(task, taskID)
    task_in_doc = find_tasks_by_id([task.refID,task.taskID].first)
    old_ref_id = task.add_task_id!(taskID)
    task_in_doc = task.raw_data
    
    @raw_file = export_raw_file
    @raw_file.gsub!(Regexp.new("\"#{old_ref_id}\""),"\"#{task.refID}\"")

    @doc = XmlSimple.xml_in(@raw_file)
    process_tasks
  rescue Exception => e
    puts [task,e].join('|||')
    puts "sorry but it's just too scary to continue given updating the task in file land didn't work"
    exit -1
  end

  #======= / OmniPlan File Modifications / =====
  
  #======== \ Task Creation \ ==============

  def process_tasks
    #OmniPlan indicates it's "top-task" by the top-task node so find that first
    # We get the idref for the task then do a search of the doc by id and get the root node
    root_node_id = @doc['top-task'].first['idref']
    root_node = find_tasks('id', root_node_id).first


    #Now we need to find all of the dependents of that "top-task"
    #These are the actual top level tasks
    #Each of these top level tasks will be considered a project
    projects_raw = find_tasks('id', child_refs(root_node))

    #Do some quick initialization and we'll be off
    @sprints = []

    # For each project node build recursively build the tree of tasks below it
    projects_raw.each do |project_raw|
       task = build_task(project_raw, 0)
       build_children(task)
       @sprints << task
    end

    true
  end

  def build_task(raw_data_in, level)
    task = OmniTask.new(raw_data_in, level)
    assign_resource_name_for_task(task)
    task
  end

  # Used to assign a resource name to a task by reference
  def assign_resource_name_for_task(task)
    resource = find_resource_by_id(task.owner_ref) || []
    unless resource.empty?
      task.owner_name = resource.first['name'].first
    end
  end

  #Used to recursively build a tree of tasks for a particular node
  def build_children(task, level = 0)
    #First find the resource
    assign_resource_name_for_task(task)

    # Find the child_refs of the current node
    # For each of the children refs found create a new OmniTask instance 
    # (we cheat with level because it's easier)
    task.children = find_tasks('id', child_refs(task)).map{|raw| build_task(raw, level + 1)}

    # Now take each of the children found, and recurse
    # Note we only increment level + 1 to the child calls. 
    # Each child is responsible for giving its "grand-children" the correct level
    task.children.each do |sub_task|
      build_children(sub_task, level + 1)
    end
  end

  def flat_task_list(task, include_self = true)
    result = include_self ? [task] : []
    result <<
      task.children.map do |child|
        flat_task_list(child)
      end
    result.flatten
  end
  #======== / Task Creation / ==============


  #======= \ Helpers \ =====

  def find_resource_by_id(id)
    resources.select{|resource| resource['id'] == id}
  end

  def find_tasks_by_id(value)
    find_tasks('id',value)
  end

  def find_tasks(key, value)
    val = if value.is_a?(Array)
      tasks.select{|task| value.include?(task[key])}
    else
      tasks.select{|task| task[key] == value}
    end
    val || []
  end

  #Finds the child idrefs of a particular node
  def child_refs(node)
    if node.is_a?(Hash)
      node['child-task'].map{|child| child['idref']}
    else
      node.child_refs 
    end
  end

  def resources
     @doc['resource'][1..-1]
  end

  def tasks
    @doc['task']
  end

  def to_s
    sprints
  end
 
  #======= / Helpers / =====

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
  def to_s
    sprints.each do |sprint|
      sprint.to_s
    end
  end

=end
