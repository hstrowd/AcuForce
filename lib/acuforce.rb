#!/usr/bin/env ruby
#INITAL DEVELOPMENT
#askryl
#https://github.com/skryl/AcuForce.git

#bfeigin intense modifications
#Ripped out most of AcuForce, kept the basic Acunote logic see AcunoteBase
#https://github.com/bfeigin/AcuForce.git

#Major modifications to transition from OmniPlan to Accunote
#Notes there are a few gems required see directly below :)

require 'psych'
require 'rubygems'
require 'acunote_connection'
require 'acunote_project'
require 'acunote_sprint'

DEBUG = true unless defined? DEBUG
