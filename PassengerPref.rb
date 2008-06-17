#
#  PassengerPref.m
#  Passenger
#
#  Created by Eloy Duran on 5/8/08.
#  Copyright (c) 2008 Eloy Duran. All rights reserved.
#

require 'osx/cocoa'
include OSX

OSX.require_framework 'PreferencePanes'
OSX.load_bridge_support_file File.expand_path('../Security.bridgesupport', __FILE__)

require File.expand_path('../shared_passenger_behaviour', __FILE__)
require File.expand_path('../PassengerApplication', __FILE__)
require File.expand_path('../TheButtonWhichOnlyLooksPretty', __FILE__)

class PrefPanePassenger < NSPreferencePane
  include SharedPassengerBehaviour
  
  PASSENGER_CONFIG_INSTALLER = File.expand_path('../passenger_config_installer.rb', __FILE__)
  
  ib_outlet :installPassengerWarning
  
  ib_outlet :authorizationView
  
  ib_outlet :applicationsTableView
  ib_outlet :applicationsController
  
  kvc_accessor :applications, :authorized
  
  def mainViewDidLoad
    @authorized = false
    
    @authorizationView.string = OSX::KAuthorizationRightExecute
    @authorizationView.delegate = self
    @authorizationView.updateStatus self
    @authorizationView.autoupdate = true
    
    @applications = [].to_ns
    
    @applicationsTableView.dataSource = self
    @applicationsTableView.registerForDraggedTypes [OSX::NSFilenamesPboardType]
    
    @installPassengerWarning.hidden = passenger_installed?
    
    Dir.glob(File.join(USERS_APACHE_PASSENGER_APPS_DIR, '*.vhost.conf')).each do |app|
      @applicationsController.addObject PassengerApplication.alloc.initWithFile(app)
    end
  end
  
  def remove(sender)
    apps = @applicationsController.selectedObjects
    apps.each { |app| app.remove }
    @applicationsController.removeObjects apps
  end
  
  def showInstallPassengerHelpAlert(sender)
    alert = OSX::NSAlert.alloc.init
    alert.messageText = "Install Passenger Gem"
    alert.informativeText = "The Passenger Preference Pane uses the gem command to locate your Passenger installation.\n\nTo install the current release use:\n“$ sudo gem install passenger”\n“$ sudo passenger-install-apache2-module”\n\nAfter installing the Passenger gem, load the Passenger Preference Pane again and we’ll setup your Apache config for you. (You can ignore the instructions about this during the installation process.)"
    alert.runModal
  end
  
  # Select application directory panel
  
  def rbSetValue_forKey(value, key)
    super
    browse if key == 'applications' and value.last.new_app?
  end
  
  def browse(sender = nil)
    panel = NSOpenPanel.openPanel
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.objc_send(
      :beginSheetForDirectory, @applicationsController.selectedObjects.first.path,
      :file, nil,
      :types, nil,
      :modalForWindow, mainView.window,
      :modalDelegate, self,
      :didEndSelector, 'openPanelDidEnd:returnCode:contextInfo:',
      :contextInfo, nil
    )
  end
  
  def openPanelDidEnd_returnCode_contextInfo(panel, button, contextInfo)
    @applicationsController.selectedObjects.first.setValue_forKey(panel.filename, 'path') if button == OSX::NSOKButton
  end
  
  # Applications NSTableView dataSource drag and drop methods
  
  def tableView_validateDrop_proposedRow_proposedDropOperation(tableView, info, row, operation)
    files = info.draggingPasteboard.propertyListForType(OSX::NSFilenamesPboardType)
    if files.all? { |f| File.directory? f }
      OSX::NSDragOperationGeneric
    else
      OSX::NSDragOperationNone
    end
  end
  
  def tableView_acceptDrop_row_dropOperation(tableView, info, row, operation)
    apps = info.draggingPasteboard.propertyListForType(OSX::NSFilenamesPboardType).map { |path| PassengerApplication.alloc.initWithPath(path) }
    @applicationsController.addObjects apps
    PassengerApplication.startApplications apps
  end
  
  # SFAuthorizationView: TODO this should actualy move to the SecurityHelper, but for some reason in prototyping it didn't work, try again when everything is cleaned up.
  
  def authorizationViewDidAuthorize(authorizationView = nil)
    p 'authorizationViewDidAuthorize'
    OSX::SecurityHelper.sharedInstance.authorizationRef = @authorizationView.authorization.authorizationRef
    p OSX::SecurityHelper.sharedInstance.authorized?
    self.authorized = true
  end
  
  def authorizationViewDidDeauthorize(authorizationView = nil)
    p 'authorizationViewDidDeauthorize'
    OSX::SecurityHelper.sharedInstance.deauthorize
    p OSX::SecurityHelper.sharedInstance.authorized?
    self.authorized = false
  end
  
  private
  
  def passenger_installed?
    `/usr/bin/gem list passenger`.include? 'passenger'
  end
end
