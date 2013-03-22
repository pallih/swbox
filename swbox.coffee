#!/usr/bin/env coffee

fs = require 'fs' 

__version = '0.0.4'

exec = require('child_process').exec

write = (text) ->
  process.stdout.write "#{text}\n"

warn = (text) ->
  process.stderr.write "#{text}\n"

showVersion = ->
  write "swbox #{__version}"
  write '© Zarino Zappia, AGPL Licensed'

showHelp = ->
    write 'swbox:\tA command line interface for interacting with ScraperWiki boxes'
    write 'Usage:\tswbox <command> [args]'
    write 'Commands:'
    write '\tswbox mount <boxName>\t\tMount <boxName> as an sshfs drive'
    write '\tswbox unmount <boxName>\t\tUnmount the <boxName> sshfs drive'
    write '\tswbox clone <boxName> <dest>\tMake a local copy of the entire contents of <boxName>'
    write '\t\t\t\t\tDestination directory <dest> is optional, defaults to <boxName>'
    write '\tswbox update\t\t\tDownload latest version of swbox'
    write '\tswbox [-v|--version]\t\tShow version & license info'
    write '\tswbox help\t\t\tShow this documentation'

mountBox = ->
  args = process.argv[3..]
  if args.length == 1
    boxName = args[0]
    path = "/tmp/ssh/#{boxName}"
    exec "mkdir -p #{path} && sshfs #{boxName}@box.scraperwiki.com:. #{path} -ovolname=#{boxName} -oBatchMode=yes -oworkaround=rename", {timeout: 5000}, (err, stdout, stderr) ->
      if err?
        if "#{err}".indexOf('sshfs: command not found') > -1
          warn 'sshfs is not installed!'
          warn 'You can find it here: http://osxfuse.github.com'
        else if "#{err}".indexOf('remote host has disconnected') > -1
          warn 'Error: The box server did not respond.'
          warn "The box ‘#{boxName}’ might not exist, or your SSH key might not be associated with it."
          warn 'Make sure you can see the box in your Data Hub on http://x.scraperwiki.com'
          exec "rmdir #{path}", (err) ->
            if err? then warn "Additionally, we enountered an error while removing the temporary directory at #{path}"
        else
          warn 'Unexpected error:'
          warn err
      else
        write "Box mounted:\t#{path}"
  else
    write 'Please supply exactly one <boxName> argument'
    write 'Usage:'
    write '\tswbox mount <boxName>\tMount <boxName> as an sshfs drive'

unmountBox = ->
  args = process.argv[3..]
  if args.length == 1
    boxName = args[0]
    path = "/tmp/ssh/#{boxName}"
    exec "umount #{path}", (err, stdout, stderr) ->
      if err?
        if "#{err}".indexOf 'not currently mounted' > -1
          warn "Error: #{boxName} is not currently mounted"
        else
          warn 'Unexpected error:'
          warn err
      else
        write "Box unmounted:\t#{boxName}"
  else
    write 'Please supply exactly one <boxName> argument'
    write 'Usage:'
    write '\tswbox unmount <boxName>\tUnmount the <boxName> sshfs drive'

cloneBox = ->
  args = process.argv[3..]
  if args.length > 0
    boxName = args[0]
    destination = args[1] or boxName
    write "Cloning box ‘#{boxName}’ to directory #{process.cwd()}/#{destination}..."
    # command = """scp -r -o "BatchMode yes" #{boxName}@box.scraperwiki.com:~ #{process.cwd()}/#{destination}"""
    command = """rsync -avx --delete-excluded -e 'ssh -o "NumberOfPasswordPrompts 0"' #{boxName}@box.scraperwiki.com:. #{process.cwd()}/#{destination}"""
    exec command, (err, stdout, stderr) ->
      if stderr.match /^Permission denied/
        warn 'Error: Permission denied.'
        warn "The box ‘#{boxName}’ might not exist, or your SSH key might not be associated with it."
        warn 'Make sure you can see the box in your Data Hub on http://x.scraperwiki.com'
      else if err or stderr
        warn "Unexpected error:"
        warn err or stderr
      else
        write "Saving settings into #{destination}/.swbox..."
        settings =
          boxName: boxName
        fs.writeFileSync "#{destination}/.swbox", JSON.stringify(settings, null, 2)
        write "Box cloned to #{destination}"
  else
    write 'Please supply a <boxName> argument, and an optional directory into which to clone the files'
    write 'Usage:'
    write '\tswbox clone <boxName> <dest>\tMake a local copy of the entire contents of <boxName>'
    write '\t\t\t\t\tDestination directory <dest> is optional, defaults to <boxName>'

update = ->
  exec "cd #{__dirname}; git pull", (err, stdout, stderr) ->
    if "#{stdout}".indexOf 'Already up-to-date' == 0
      write "You're already running the latest version of swbox"
    else if not stderr
      write 'swbox has been updated!'
    else
      warn 'Error: could not update.'
      warn stderr

swbox =
  mount: mountBox
  unmount: unmountBox
  clone: cloneBox
  help: showHelp
  update: update
  '--help': showHelp
  '-v': showVersion
  '--version': showVersion

main = ->
  args = process.argv
  if args.length > 2
    if args[2] of swbox
      swbox[args[2]]()
    else
      write "Sorry, I don’t understand ‘#{args[2]}’"
      write 'Try: swbox help'
  else
    swbox.help()

main()
