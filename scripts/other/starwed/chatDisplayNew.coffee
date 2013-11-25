logit = (msg)->console.log("~CD: #{msg}")

# Necessary for contextmenu
window.nochat = false


#daemonChatSource = '<div id="outer-wrapper">		<div id="tab-wrapper">		<div id="tabs" class="tabs-bottom">			<ul id="tab-head">	</ul>	</div>	</div>	<div id="bottom-wrapper">		<div id="InputForm">			<center>				<input id="chatBox" class="TextInput"  maxlength="200" 					type="text" size="12" id="entry" autocomplete="off" />				<span id="gear" class="ui-icon ui-icon-gear">Options</span>			</center>		</div>	</div></div>'



logit("------- CHATDISPLAY SCRIPT RUNNING!   YO YO YO ----------\n")
#Object for abstracting messaging a little
class Port
	emit: (msg, data)=>
		self.port.emit(msg, data)

	on: (msg, callback)=>
		self.port.on(msg, callback)

class DirectPort
	link: null
	emit: (msg, data) => @link.trigger(msg, data)
	on: (msg, callback) => @listeners[msg] = callback
	listeners: []
	trigger: (msg, data) =>
		if @listeners[msg]?
			@listeners[msg](data)

MenuObject =  {
	title: 'Actions',
	items: [
		{
			label:'Open private tab',
			action: (e)=> 
				try 
					pname = $(e.target).closest('[pname]').attr('pname')
					pid  = $(e.target).closest('[pid]').attr('pid')
					displayer.addTab(pid, 'private', pname)
				catch e
					logit(e)
		}
	]
}



MenuAction = (e, action)-> 
	pname = $(e.target).closest('[pname]').attr('pname')
	porter.emit("doPlayerAction", {"name":pname, "action":action})
	



class ChatDisplay
	openTabs: []	
	#tabWindows: []
	tabInfo: []
	openChannel: null
	playername: ""

	commandHistory: []
	commandMemory: 15
	commandMarker: null
	$tabs: null


	selectedTab: null

	objectLog: []

	showOpt: true
	#Prefs
	prefs: []

	logTab: off
	logInChat: off
	$log: null

	currentTab:  => 
		tabIndex = $("#tabs").tabs("option", "selected")
		return @openTabs[tabIndex]
	getWindow: (tab) => 
		return $("#" + "#{tab}")

	getTabHeader: (tab) =>
		#logit("Getting header for #{tab}")
		return $('#tab-head > li >a[href="#' + tab + '"]').parent()

	clearMessages: (tab) =>
		$(".output", @getWindow(tab) ).each( ()-> $(this).remove() )
		$("hr.marker", @getWindow(tab) ).remove()


	selectTab: (tab) =>
		try
			index = $( "li", @$tabs ).index( @getTabHeader(tab) )
			#logit(index)
			@$tabs.tabs("select", index)
			@setSize()			
			$("#chatBox").select()
		catch e
			logit("#{e}")




	tabRight: ()=>
		tabIndex = @$tabs.tabs("option", "selected")
		if tabIndex >= @openTabs.length-1
			@$tabs.tabs("select", 0)
		else
			@$tabs.tabs("select", tabIndex+1)
			

	tabLeft: ()=>	
		tabIndex = @$tabs.tabs("option", "selected")		
		if tabIndex is 0
			@$tabs.tabs("select", @openTabs.length-1)
		else
			@$tabs.tabs("select", tabIndex-1)


	setOwnInfo: (payload) =>
		setClanInfo = (tabName) =>
			logit("setting clan info for #{tabName}")
			clanwindow = @getWindow(tabName)
			headerHTML = """<b>#{payload.header.clan}</b>"""
			clanwindow.children(".chatInfo").html(headerHTML)
			clanwindow.children(".chatInfo").addClass('clanInfo')			
		#Set info for all channels associated with a clan
		logit("The header info is #{payload.header.toSource()}")
		setClanInfo(tab) for tab in ['clan', 'hobopolis', 'slimetube', 'hauntedhouse', 'private', 'dread']
		@setSize()
		

	setPlayerHeader: (payload) =>
		if not payload.header?
			return
		if payload.name is @playername
			@setOwnInfo(payload)

		chatwindow = @getWindow(payload.id)
		lead=payload.header.info.match(/^(.+?)<\s*?br/)
		#logit("INFO IS #{payload.header.info}")
		if lead?
			payload.header.info = payload.header.info.replace(lead[1], "<a class='headerName' pname='#{payload.name}'>" + lead[1] + "</a>")

		statusclass = payload.status
		headerHTML = """
			<table width='100%' class=#{statusclass}><tr>
			<td><div>#{payload.header.info}</div></td>
			<td width = '30'><img src='#{payload.header.avatar}' height='50' width='30'/><br/><small class='status #{statusclass}'>#{payload.status}</small></td>
			</tr>
			</table>
		"""
		chatwindow.children(".chatInfo").html(headerHTML)
		$(".chatInfo a", chatwindow)
			.each( @formatLink)
			#.contextPopup(MenuObject)

		@setSize()
		

	# Public channels should have the same id & label
	# Private channels will have an id=playerID, and label=playerName
	# This prevents any fucking confusion about spaces etc.
	addTab: (id, type, name) => 
		try
			if not name?
				name = id
			if id?
				logit("adding tab for #{id}")
				if type is 'log'
					info = '<b>System Log</b>'
					label = name
				else if type is 'private'
					porter.emit("requestPlayerInfo", {"name":name})
					label = '#' + name
					info = "...loading info for #{name}..."
				else
					info = ''
					label = name
				$("#tabs").tabs( "add", "##{id}", label )
				
				
				$opt = $("<div/>").addClass('chatOpt')

				clearClick = ()=> @clearMessages( @currentTab() )
				$clear = $("<a title='Clear green chat ouput (/clear)'>clear output</a>").click(clearClick)
				$opt.append($clear)

				prefClick = ()=> porter.emit("openPreferences")
				$prefs = $("&nbsp;&nbsp;<a title='Open addon settings (/prefs)'>settings</a>").click(prefClick)
				$opt.append($prefs)
				
				ct = $( "##{id}")
					.addClass("chatTab")
					.append("<div class='chatInfo'>#{info}</div>")
					.append("<div class='ChatWindow'><br/></div>")
					.append($opt)

				@tabInfo[id] = 
					'window': $(".ChatWindow", ct)
					'id':id
					'type':	type
					'label': label
					'name': name

				@openTabs.push(id)
				@setSize()

		catch e
			logit("Error while adding tab #{id}: #{e}")
				
	
	refreshTimeStamps: ()=> $(".timestamp").toggle(@prefs.timestampsOn)
		
	
	#called in a context where this points to a link's dom node
	formatLink: () ->

		target = $(this).attr('target')
		href = $(this).attr('href')
		plname =  $(this).attr('pname')
		logit("\n\nFormatting link!")
		if plname?.length>0	
			$(this).click(
				()->
					logit("SEEKING TO LOAD PLAYER #{plname}")
					porter.emit("loadPlayer", {"name":plname})
					return false
			)
		
		else if href.match(/who=\d+/)

			plname = $(this).text().match(/([\w\s]+)/)[1]
			pid = href.match(/who=(\d+)/)[1]
			logit("Found player match for #{plname}, (#{pid})")
			$(this).attr('pname', plname)
				.attr('pid', pid)
				.attr('href', "showplayer.php?who=#{pid}")
			$(this).click(
				()->
					logit("SEEKING TO LOAD PLAYER #{plname}")
					porter.emit("loadLink", {"path":href})
					return false
			)
		else if target is 'mainpane'	
			$(this).attr('starwed', 'isMainpane')
			$(this).click(
				()->
					rawtext = $(this).text()
					pname = rawtext.match(/[\w\s]+/)
					if pname isnt null
						pname = pname[0]
						#porter.emit("loadLink")
					
					#logit("CLICK NAME IS: |#{pname}|")
					porter.emit("loadLink", {"path":href})

					return false
			)
		else
			$(this).attr('starwed', 'touchedButNotMain')

	createTimeStamp: (msg) =>
		date = new Date(msg.timestamp)
		logit("Transmitted timestamp: " + msg.timestamp)
		minutes = date.getMinutes()
		hours = date.getHours()
		if minutes < 10 
			minutes = "0" + minutes
		logit("Hours are #{hours}")
		return "[#{hours}:#{minutes}]"
		


	createSpeaker: (msg) =>
		try
			if (not msg.who?) then return $("")
			if msg.format == '1' then return $("")
			if msg.who.displayName? 
				dName = msg.who.displayName
			else
				dName = msg.who.name

			return $("<a class='player' target='mainpane'>#{dName}</a>")
				.css('color', msg.who.color)
				.attr('pname', msg.who.name)
				.attr('pid', msg.who.id)				
				.attr('href', "showplayer.php?who=#{msg.who.id}")
				#.attr('title', "#{msg.who.name} (#{msg.who.id})")
		catch e
			logit("Error speaker making #{e}")

	setSpeakerId: (who) =>
		logit("attempting to set speaker id for #{who.toSource()}")
		selector = """a[pname="#{who.name}"]"""		
		$(selector).each(
			()->			
				$(this).attr('pid', who.id)
				$(this).attr('href', "showplayer.php?who=#{who.id}")
		)

	createGuts: (msg) =>
		# if the message has a speaker who is not emoting...
		try
			if msg.who? and not (msg.format is '1')
				delimiter = ":"
			else
				delimiter = ""
			$msg = $("<span class='guts'>#{delimiter}  #{msg.msg}</span>")
			if msg.link? and msg.type is 'event' and msg.link isnt 'false' and msg.link isnt false
				logit('trying to wrap message in link')
				$msg = $( "<a href='#{msg.link}' target='mainpane' class='event' />").append($msg)
		catch e
			logit("Error creating guts #{e}")
		return $msg
		

	createMsgLine: (msg) =>
		try
			timestamp = @createTimeStamp(msg)
			$timestamp =  $("<span  class='timestamp'>#{timestamp}</span>").toggle(@prefs.timestampsOn)

			$speaker = @createSpeaker(msg)
			$guts = @createGuts(msg)
			$msgLine = $("<div/>")
				.append($timestamp)
				.append($speaker)
				.append($guts)
				.attr("title", timestamp)
				#.attr("rawSource", msg.toSource())	#Debugging info
		catch e
			logit("error creating msgline #{e}")

		return $msgLine
		
	formatMsgLine: ($msgLine, msg) =>
		logit("Formatting msgline")
		if msg.type is 'output' 
			$msgLine.addClass('output')
			#http://stackoverflow.com/questions/562134/how-to-match-first-child-of-an-element-only-if-its-not-preceeded-by-a-text-node
			firstFilter = ()->
				prev = this.previousSibling
				logit("prev is " +  prev?.nodeName  + "and type is " + prev?.nodeType)
				logit("Logicks are #{not prev} and #{prev?.nodeType !=3}" )
				return ((not prev) or   (prev.nodeType == 3 and prev.nodeValue.match(/^\s*$/) ) )
			lastFilter = ()->
				next = this.nextSibling
				logit("next is " +  next?.nodeName  + "and type is " + next?.nodeType)
				return ((not next) or   (next.nodeType == 3 and next.nodeValue.match(/^\s*$/) ) )
			$("span.guts > br", $msgLine).filter(firstFilter).remove()
			#$("br:first-child", $msgLine).remove()
			$("span.guts > br", $msgLine).filter(lastFilter).remove()

			#$("br", $msgLine).replaceWith("<hr class='output-rule' />")
		else
			$msgLine.addClass("msg")

		if (msg.type is 'output' or msg.type is 'system' or msg.type is 'event' or (msg.type is 'public' and (msg.format is 98 or msg.format is 3 or msg.format is 4 or msg.format is 2)))
			$msgLine.addClass('boxmsg')
			$msgLine.append("<span class='ui-icon ui-icon-close'>Remove Tab</span>")

		if msg.type is 'output'
			$msgLine.addClass('output')

		if msg.type is 'event'
			$msgLine.addClass('event')

		if msg.type is 'system'
			$msgLine.addClass('system')

		if msg.type is 'public'
			switch msg.format
				when '0', '1', '2', '3', '4'
					$msgLine.addClass('talking')
			formats = [0: '', 1:'emote', 2:'system-red', 3:'warn', 4:'annc', 98:'event', 99:'welcome']
			$msgLine.addClass(formats[msg.format])
			if msg.format is 2 or msg.format is 3 or msg.format is 4
				$msgLine.addClass('system')
			if msg.format is 98
				$msgLine.addClass('event')

			# Find the player link in the emote block and add player class
			# (Why cdm, why?)
			if msg.format == '1'
				$('a', $msgLine).first().addClass('player')
			
		if msg.type is 'private'
			$msgLine.addClass('talking')

		if msg.important
			$msgLine.addClass('important')

		$("a", $msgLine).each( @formatLink)

		#Add context menu to player links
		#$msgLine.find("[pname]").contextPopup(MenuObject)

		return $msgLine




			
	displayMsg: (payload) => 
		logit("recieved message: #{payload.toSource()}")

		
		# = @objectLog.push(payload) - 1
		#logit("Displaying Message")
		tab = payload.channel
		msg = payload.msg
		type = payload.type

		doscroll = false
		addMarker = false

		#console.log("Current: #{@currentTab()} and type: #{payload.channel}")
		if type is 'private' and @currentTab() isnt payload.channel and payload.who?.id is payload.channel and @prefs.pmEvents is on
			fakeMsg = 
				"type":"event" 
				"msg":"#{payload.who.name} just messaged you!"
				"timestamp": payload.timestamp
				"channel": "!!current"
			@displayMsg(fakeMsg)

		#Get the base message text before we add timestamps etc.
		baseMsg = $("<div>#{msg}</div>").text()

		if tab is "!!current"
			tab = @currentTab()
		try
			if not tab?
				return
			
			if not @tabInfo[tab]? 
				@addTab(tab, type, payload.tabName)

			chatWindow = @tabInfo[tab].window

			#Note unread messages, flash if important. 
			if tab isnt @currentTab()
				if payload.self is true 
					@selectTab(tab)
			
				else
					@getTabHeader(tab).css("font-style", 'italic')
					if @prefs.loudTabs is on
						@getTabHeader(tab).addClass('loud')
						@getTabHeader(tab).stop(true, true).effect('pulsate', {times:1}, 600)
						#@getTabHeader(tab).effect('bounce', {times:1, direction:"up", distance:"5"}, 400)
						@setSize()	
					if payload.important is true or payload.type is 'private'
						@getTabHeader(tab).stop(true, true).effect('pulsate', {times:3}, 700)
						@getTabHeader(tab).addClass('important')
						@setSize()		
					
					if $("hr.marker", chatWindow).length is 0 and @prefs.chatMarkers is on
						addMarker = true
					
					
			
		

			doscroll = @checkScroll(chatWindow)
			
			$msg = @createMsgLine(payload)
			$msg = @formatMsgLine($msg, payload)


			

		
			#add the message to the system log if appropriate
			if type is 'system' #or type is 'system-red'
				@$log.append($msg.clone())

			
			# Don't add system messages if persist is set to 0
			if (type isnt 'output') or ( parseFloat(@prefs.persistSystemMessages)!=0)
				#Add a marker if necessary, but hide it if there's no text yet!
				if addMarker is true	
					chatWindow.append("<hr class='marker'/>")
					if $("div",chatWindow).length is 0
						$("hr.marker", chatWindow).toggle(off)
				chatWindow.append($msg)

			logit("ADDED MESSAGE TO WINDOW?")

			#Remove note after a while if that pref is a positive number
			if type is 'output' and parseFloat(@prefs.persistSystemMessages)>0
				target = $msg.get(0)
				removeMsg =  ()=> target.parentNode.removeChild(target)
				window.setTimeout( removeMsg,  @prefs.persistSystemMessages * 1000 )
			if (type is 'output' or type is 'system' or type is 'event') and @prefs.notifyOn is on
				porter.emit("kdNotify", {title:'Kol Chat', msg:baseMsg})
			if type is 'private' and @prefs.pmNotifyOn is on and payload.self is false
				porter.emit("kdNotify", {title:"Private from #{payload.speaker}", msg:baseMsg})
			@scroll(chatWindow) if doscroll	
		catch e
			logit("Error in displayMsg: #{e}")

		

	
	# returns true if we need to scrollb
	checkScroll:  (cw)=> ( cw.outerHeight() + cw.scrollTop() + 5 > cw[0].scrollHeight )

	scroll: (cw) => cw.animate({scrollTop: cw[0].scrollHeight})

	sendChatMessage: () => 
		try
			# If we're sending a message, reset commandhistory
			if @commandMarker != null
				@commandMarker = null
				@commandHistory.shift()
			
			msg = $("#chatBox ").val()
			if msg!= @commandHistory[0]
				@commandHistory.unshift(msg)
			if @commandHistory.length > @commandMemory
				@commandHistory.pop()
			$("#chatBox").val("")

			#Handle special chat messages
			if @handleSpecialCommands(msg)
				return
			else
				ctInfo = @tabInfo[@currentTab()]
				porter.emit("newChatSubmission", {"msg":msg, "currentTab":ctInfo })
		catch e
			logit('error sending chat: ' + e)


	handleSpecialCommands: (msg) =>
		logit("hsc:     |#{msg.trim()}|")
		try 
			logit(msg.indexOf("/clear"))
			switch msg.trim()
				when "/clear" then @clearMessages( @currentTab() )
				when "/prefs" then porter.emit("openPreferences")
				else return false
			return true
		catch e
			logit("hsc error: #{e}")
			return false




	startHistory: =>
		@commandHistory.unshift($("#chatBox ").val() )
		@commandMarker = 0

	historyUp: =>
		if @commandMarker is null then @startHistory()
		@commandMarker+=1
		if @commandMarker >= @commandHistory.length then @commandMarker = 0
		$("#chatBox ").val(@commandHistory[ @commandMarker])
	
	historyDown: =>
		if @commandMarker is null then @startHistory()
		@commandMarker-=1
		if @commandMarker < 0 then @commandMarker = @commandHistory.length
		$("#chatBox ").val(@commandHistory[ @commandMarker])

	removeTabByIndex: (index) =>
		logit('removing tab?')
		try
			tab =  @openTabs[index]
			@$tabs.tabs("remove", index)
			@openTabs.splice(index, 1)
			@tabInfo[tab] = null
		catch e
			logit("#{e}")

	setSize: =>
		#Set display of options, before setting size!
		$(".chatOpt").toggle(@showOpt)	

		tabHeight = $("#tab-head").height();
		inputHeight = $("#bottom-wrapper").height();
		totalHeight = $("#outer-wrapper").height();
		$("#tab-wrapper" ).height(totalHeight - inputHeight);
		$("#tabs" ).height(totalHeight - inputHeight);
		$(".chatTab" ).each( ()->  
			infoHeight = $(this).children('.chatInfo').height() 
			if $(this).children('.chatOpt').css('display') is 'none'
				optHeight =  0
			else
				optHeight =  $(this).children('.chatOpt').height()
			$(this).height(  (totalHeight-tabHeight - inputHeight) ) 
			$(this).children('.ChatWindow').height(totalHeight-tabHeight - inputHeight-infoHeight - optHeight)
			
		)

	
	onSelect: (event, ui)=>
		@getTabHeader( @openTabs[ui.index]  )
			.css("font-style", 'normal').removeClass('important').removeClass('loud')
		$("#chatBox").select()
		if @selectedTab?
			try 
				oldTab = @currentTab()		#This runs before actual selection happens!
				@selectedTab = @openTabs[ui.index]
				logit("\nCurrent tab is #{@selectedTab}")
				#Remove any markers when switching away from a tab -- we'll want new ones!
				console.log("Removing marker from tab #{oldTab}\n\n")
				$("hr.marker", @tabInfo[oldTab].window ).remove()
			catch e
				logit( "HR error: #{e}")
		@setSize()


	setPlayerStatus: (data)=>
		alert(data.status)

	start: ()=>
		
		try
			logit("__ I AM STARTING CHAT __")
			#window.document.body.innerHTML = daemonChatSource

			#porter.emit("chatDisplayReady")
		
			tabOptions = {
				select: @onSelect
				show: @setSize
				tabTemplate:''' <li>
									<a href='#{href}'>#{label}</a> 
									<span class='ui-icon ui-icon-close'>Remove Tab</span>
									<span class='ui-icon ui-icon-comment'>Message!</span>
								</li> ''' 
							
			}
			$("#tabs").tabs(tabOptions);

			@$tabs= $("#tabs").tabs()

			# If we want bottom tabs instead of top tabs
			# Suggested by jqueryUI, but honestly seems pretty shite, so not an option for now
			###
			$( ".tabs-bottom .ui-tabs-nav, .tabs-bottom .ui-tabs-nav > *" )
				.removeClass( "ui-corner-all ui-corner-top" )
				.addClass( "ui-corner-bottom" );
			###
			

			@$log=$("<div class='log'></div>")
			
			$(window).resize( @setSize)
			@setSize()

			
			# Bind the up/down keys only when the textbox has focus.  
			# but the (opt) left right keys should occur anytime the frame is in focus
			$("#chatBox")
				.keyup( 
					(e)=>
						if e.keyCode is 13 then @sendChatMessage() 
						## up/down are 38/40
						if e.keyCode is 38 and e.shiftKey is true then @historyUp()
						if e.keyCode is 40 and e.shiftKey is true then @historyDown()

				)
			$("body").keyup(
				(e)=>				
					if e.keyCode is 37 and e.ctrlKey is true then @tabLeft()
					if e.keyCode is 39 and e.ctrlKey is true then @tabRight()
					## left/right are 37/39		
			)
			
			cd = this
			closeThisTab = ($target)->
				$tabs = $("#tabs")
				index = $( "li", $tabs ).index( $target );
				cd.removeTabByIndex(index)

			# block of on/live handlers


			$("#tab-head li").live( 'dblclick', ()->closeThisTab( $(this)) )
			$( "#tab-head span.ui-icon-close").live('click', ()->closeThisTab($(this).parent() ))
			$("span.ui-icon-gear").live('click', 
				()=>		
					logit("Flipping showOpt! \n")			 
					@showOpt = not @showOpt
					@setSize()
			)
			# Remove system message on clicking the X
			$(".boxmsg span.ui-icon-close").live('click', ()-> $( this ).parent().remove() )
			

			###
			$(document).on( 'dblclick', "#tab-head li", ()->closeThisTab( $(this)) )
			$(document).on('click', "#tab-head span.ui-icon-close", ()->closeThisTab($(this).parent() ))
			$(document).on('click', "span.ui-icon-gear"
				()=>		
					logit("Flipping showOpt! \n")			 
					@showOpt = not @showOpt
					@setSize()
			)
			
			# Remove system message on clicking the X
			$(document).on('click', ".boxmsg span.ui-icon-close", ()-> $( this ).parent().remove() )
			###


			#We're done, so let main thread know that!  Then wait for response to go go go.
			porter.emit("chatDisplayReady")

			#Set responses to various messages
			porter.on("chatDisplayInitData", @init)
			logit("-a-")
			porter.on("setPrefs", @setPrefs)
			logit("-b-")
			porter.on("newChatMessage", @displayMsg )
			logit("-c-")
			porter.on("setPlayerHeader", @setPlayerHeader)
			porter.on("setPlayerInfo", @setPlayerHeader)
			logit("-d-")
			porter.on("setSpeakerId", @setSpeakerId)
			#porter.on("setPlayerStatus", @setPlayerStatus)

			

			logit("DONE START")
		catch e
			logit("Error starting: #{e}")
	
	init: (payload) =>	
		#logit("\nInitial payload: #{payload.toSource()}")
		@openChannel=payload.openChannel
		@playername = payload.playername
		logit('about to add menu options')
		@addMenuOptions(payload.menu)
		@addTab(@openChannel, 'public', @openChannel)
		@selectedTab = @openChannel

	addMenuOptions: (menu)=>
		logit("MENU IS #{menu.toSource()}")
		try
			actionHandlerFactory = (loc)-> (e)->MenuAction(e, loc)
			for root, args of menu
				if(args.action is 1)
					location = root + "?" + args.arg
					MenuItem = 
						"label": args.title
						"action": actionHandlerFactory(location)
					MenuObject.items.push(MenuItem)
		catch e
			logit("\n\nMenu problem: #{e}")


	setPrefs: (payload) =>
		#logit('setting prefs')
		oldPrefs = @prefs
		@prefs = payload.prefs
		logit(oldPrefs.toSource() )
		try 
			for p of oldPrefs
				if oldPrefs[p]!=@prefs[p] then @onPrefChange(p)
		catch e
			logit("Error #{e}")

	# Actions to be taken on the change of a pref
	onPrefChange: (p) =>
		switch p
			when 'timestampsOn'
				@refreshTimeStamps()

displayer = new ChatDisplay()
porter = null


startChat = ()-> 
	porter = window.globalPort
	displayer.setPrefs(window.globalPrefs)
	displayer.start()
window.onload = startChat










