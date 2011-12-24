require 'spec_helper'

describe 'Acufore Loading' do
  it 'should be able to load the Connection API' do
    AcunoteConnection.should === AcunoteConnection.instance
  end
  it 'should be able to load the Project API' do
    AcunoteProject.should === AcunoteProject.new
  end
  it 'should be able to load the Sprint API' do
    AcunoteSprint.should === AcunoteSprint.new
  end
end
