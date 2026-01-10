#!/usr/bin/env bash

# Mac OS X configuration
# Adapted from Geerlingguy
#
# This configuration applies to the latest version of macOS (currently 11.3),
# and sets up preferences and configurations for all the built-in services and
# apps. Third-party app config should be done elsewhere.
#
# Options:
#   --no-restart: Don't restart any apps or services after running the script.
#
# If you want to figure out what default needs changing, do the following:
#
#   1. `cd /tmp`
#   2. Store current defaults in file: `defaults read > before`
#   3. Make a change to your system.
#   4. Store new defaults in file: `defaults read > after`
#   5. Diff the files: `diff before after`
#
# @see: http://secrets.blacktree.com/?showapp=com.apple.finder
# @see: https://github.com/herrbischoff/awesome-macos-command-line
#
# @author Jeff Geerling

# Warn that some commands will not be run if the script is not run as root.
if [[ $EUID -ne 0 ]]; then
  RUN_AS_ROOT=false
  printf "Certain commands will not be run without sudo privileges. To run as root, run the same command prepended with 'sudo', for example: $ sudo $0\n\n" | fold -s -w 80
else
  RUN_AS_ROOT=true
  # Update existing `sudo` timestamp until `.osx` has finished
  while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
fi

###############################################################################
# General UI/UX                                                               #
###############################################################################

# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Expand print panel by default
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Save to disk (not to iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Automatically quit printer app once the print jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# Restart automatically if the computer freezes
if [[ "$RUN_AS_ROOT" = true ]]; then
  systemsetup -setrestartfreeze on
fi



###############################################################################
# Language & Region                                                           #
###############################################################################

# Set preferred languages to NZ English and Māori
defaults write NSGlobalDomain AppleLanguages -array "en-NZ" "mi-NZ"

# Set locale to New Zealand
defaults write NSGlobalDomain AppleLocale -string "en_NZ"

# Set measurement units to metric
defaults write NSGlobalDomain AppleMeasurementUnits -string "Centimeters"
defaults write NSGlobalDomain AppleMetricUnits -bool true

# Set temperature unit to Celsius
defaults write NSGlobalDomain AppleTemperatureUnit -string "Celsius"

# Set first day of week to Monday (Western standard)
defaults write NSGlobalDomain AppleFirstWeekday -dict gregorian 2



###############################################################################
# Menu Bar                                                                    #
###############################################################################

# Show date in menu bar clock (Ventura+)
defaults write com.apple.menuextra.clock ShowDate -int 1

# 24-hour time format
defaults write NSGlobalDomain AppleICUForce24HourTime -bool false



###############################################################################
# Trackpad, mouse, Bluetooth accessories, and input                           #
###############################################################################

# Trackpad: Haptic feedback (light, silent clicking)
defaults write com.apple.AppleMultitouchTrackpad FirstClickThreshold -int 0
defaults write com.apple.AppleMultitouchTrackpad ActuationStrength -int 0

# Enable tap to click 
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Trackpad: right-click with two fingers (requires restart!)
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -int 0
defaults write NSGlobalDomain ContextMenuGesture -int 1



###############################################################################
# Keyboard & Text                                                             #
###############################################################################


# Disable press-and-hold for keys in favor of key repeat
#defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Set a blazingly fast keyboard repeat rate, and make it happen more quickly.
# (The KeyRepeat option requires logging out and back in to take effect.)
#defaults write NSGlobalDomain InitialKeyRepeat -int 20
#defaults write NSGlobalDomain KeyRepeat -int 1

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Disable smart quotes as they’re annoying when typing code
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# Disable smart dashes as they’re annoying when typing code
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Disable automatic period substitution (annoying when coding)
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Disable automatic capitalization
#defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

# Use F1, F2, etc. keys as standard function keys
defaults write NSGlobalDomain com.apple.keyboard.fnState -bool true



###############################################################################
# Keyboard Shortcuts                                                          #
###############################################################################

# Disable Spotlight keyboard shortcut (Cmd+Space) to free it for Raycast
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 "
  <dict>
    <key>enabled</key><false/>
    <key>value</key><dict>
      <key>type</key><string>standard</string>
      <key>parameters</key>
      <array>
        <integer>65535</integer>
        <integer>49</integer>
        <integer>1048576</integer>
      </array>
    </dict>
  </dict>
"

# Also disable "Show Finder search window" (Cmd+Option+Space) 
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 65 "
  <dict>
    <key>enabled</key><false/>
  </dict>
"


###############################################################################
# Finder                                                                      #
###############################################################################

# Set Desktop as the default location for new Finder windows
# For other paths, use `PfLo` and `file:///full/path/here/`
defaults write com.apple.finder NewWindowTarget -string "PfDe"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/Desktop/"

# Show icons for hard drives, servers, and removable media on the desktop
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

# Finder: show hidden files by default
# defaults write com.apple.finder AppleShowAllFiles -bool true

# Finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Finder: show status bar
defaults write com.apple.finder ShowStatusBar -bool true

# Show path bar in Finder
defaults write com.apple.finder ShowPathbar -bool true

# Finder: allow text selection in Quick Look
defaults write com.apple.finder QLEnableTextSelection -bool true

# Display full POSIX path as Finder window title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool false

# When performing a search, search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Enable spring loading for directories
defaults write NSGlobalDomain com.apple.springing.enabled -bool true

# Remove the spring loading delay for directories
defaults write NSGlobalDomain com.apple.springing.delay -float 0.1

# Avoid creating .DS_Store files on network volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# Enable snap-to-grid for icons on the desktop and in other icon views
/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist

# Set the size of icons on the desktop and in other icon views
/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:iconSize 64" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:iconSize 64" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:iconSize 64" ~/Library/Preferences/com.apple.finder.plist

# Use column view in all Finder windows by default
# Default Finder view for new windows (Icon/List/Column/Gallery)
# Nlsv = List view, icnv = Icon view, clmv = Column view, glyv = Gallery view
defaults write com.apple.finder FXPreferredViewStyle -string "clmv"

# Show the ~/Library folder
chflags nohidden ~/Library

# Expand the following File Info panes:
# "General", "Open with", and "Sharing & Permissions"
defaults write com.apple.finder FXInfoPanesExpanded -dict \
  General -bool true \
  OpenWith -bool true \
  Privileges -bool true



###############################################################################
# Spotlight                                                                   #
###############################################################################

if [[ "$RUN_AS_ROOT" = true ]]; then
  # Disable Spotlight indexing for any volume that gets mounted and has not yet
  # been indexed before.
  # Use `sudo mdutil -i off "/Volumes/foo"` to stop indexing any volume.
  sudo defaults write /.Spotlight-V100/VolumeConfiguration Exclusions -array "/Volumes"

  # Restart spotlight
  killall mds > /dev/null 2>&1
fi


###############################################################################
# Desktop & Stage Manager                                                     #
###############################################################################

# Disable click wallpaper to reveal desktop
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false

# Set background to dark-grey color
#osascript -e 'tell application "Finder" to set desktop picture to POSIX file "/System/Library/Desktop Pictures/Solid Colors/Stone.png"'



###############################################################################
# Dock, Dashboard, and hot corners                                            #
###############################################################################

# Auto-hide the Dock
defaults write com.apple.dock autohide -bool true

# Remove the auto-hiding Dock delay
#defaults write com.apple.dock autohide-delay -float 0

# Set the speed of the auto-hide animation
defaults write com.apple.dock autohide-time-modifier -float 0.5

# Set the icon size of Dock items
#defaults write com.apple.dock tilesize -int 30

# Make Dock icons of hidden applications translucent
defaults write com.apple.dock showhidden -bool true

# Minimize windows using the scale effect (or "genie" for classic)
defaults write com.apple.dock mineffect -string "scale"

# Minimize windows into application icon
defaults write com.apple.dock minimize-to-application -bool true

# Don't show recent applications in Dock
defaults write com.apple.dock show-recents -bool false

# Enable the 'reduce transparency' option. Save GPU cycles.
#defaults write com.apple.universalaccess reduceTransparency -bool true

# Hot corners
# Possible values:
#  0: no-op
#  2: Mission Control
#  3: Show application windows
#  4: Desktop
#  5: Start screen saver
#  6: Disable screen saver
#  7: Dashboard
# 10: Put display to sleep
# 11: Launchpad
# 12: Notification Center

# Bottom right screen corner → Mission Control
#defaults write com.apple.dock wvous-br-corner -int 2
#defaults write com.apple.dock wvous-br-modifier -int 0
# Top right screen corner → Desktop
defaults write com.apple.dock wvous-tr-corner -int 4
defaults write com.apple.dock wvous-tr-modifier -int 0
# Bottom left screen corner → Put display to sleep
defaults write com.apple.dock wvous-bl-corner -int 10
defaults write com.apple.dock wvous-bl-modifier -int 0

# Speed up Mission Control animations
defaults write com.apple.dock expose-animation-duration -float 0.15



###############################################################################
# Screenshots                                                                 #
###############################################################################

# Save screenshots to Downloads folder.
defaults write com.apple.screencapture location -string "${HOME}/Desktop"

# Save screenshots in PNG format (other options: BMP, GIF, JPG, PDF, TIFF)
defaults write com.apple.screencapture type -string "jpg"

# Disable shadow in screenshots
defaults write com.apple.screencapture disable-shadow -bool true



###############################################################################
# Safari & WebKit                                                             #
###############################################################################

# Enable the Develop menu and the Web Inspector in Safari
#defaults write com.apple.Safari IncludeDevelopMenu -bool true
#defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
#defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true

# Add a context menu item for showing the Web Inspector in web views
#defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

# Show full URL in Safari address bar
#defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true

# Enable Safari debug menu
#defaults write com.apple.Safari IncludeInternalDebugMenu -bool true

# Prevent Safari from opening 'safe' files automatically
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

# Hide bookmarks bar by default
#defaults write com.apple.Safari ShowFavoritesBar -bool false



###############################################################################
# Mail                                                                        #
###############################################################################

# Copy email addresses as `foo@example.com` instead of `Foo Bar <foo@example.com>` in Mail.app
defaults write com.apple.mail AddressesIncludeNameOnPasteboard -bool false



###############################################################################
# Activity Monitor                                                            #
###############################################################################

# Show the main window when launching Activity Monitor
defaults write com.apple.ActivityMonitor OpenMainWindow -bool true

# Show all processes in Activity Monitor
defaults write com.apple.ActivityMonitor ShowCategory -int 0



###############################################################################
# Messages                                                                    #
###############################################################################

# Disable smart quotes as it’s annoying for messages that contain code
defaults write com.apple.messageshelper.MessageController SOInputLineSettings -dict-add "automaticQuoteSubstitutionEnabled" -bool false

# Disable continuous spell checking
defaults write com.apple.messageshelper.MessageController SOInputLineSettings -dict-add "continuousSpellCheckingEnabled" -bool false



###############################################################################
# App Store                                                                   #
###############################################################################

# Disable in-app rating requests from apps downloaded from the App Store.
defaults write com.apple.appstore InAppReviewEnabled -int 0



###############################################################################
# Time Machine                                                                #
###############################################################################

# Prevent Time Machine from prompting to use new hard drives as backup volume
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# Disable local Time Machine snapshots
if [[ "$RUN_AS_ROOT" = true ]]; then
  sudo tmutil disablelocal
fi

###############################################################################
# Photos                                                                      #
###############################################################################

# Prevent Photos from opening automatically when devices are plugged in
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true



###############################################################################
# Kill/restart affected applications                                          #
###############################################################################

# Restart affected applications if `--no-restart` flag is not present.
if [[ ! ($* == *--no-restart*) ]]; then
  for app in "cfprefsd" "Dock" "Finder" "Mail" "SystemUIServer"; do
    killall "${app}" > /dev/null 2>&1
  done
fi

printf "Please log out and log back in to make all settings take effect.\n"
