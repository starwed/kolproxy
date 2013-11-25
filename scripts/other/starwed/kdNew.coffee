proxy = true



defaultPrefs = 
	timestampsOn: false
	persistSystemMessages: -1
	watchWords: ""
	pmEvents: false
	splitPvP: true
	loudTabs: false
	notifyOn: false
	pmNotifyOn: false
	proxyTrigger: true
	chatMarkers: true



if not Object.prototype.toSource
	Object.prototype.toSource = Object.prototype.toString



# TODO


# Make notification preferences better / explain them more

# MINOR
# Bail on characterinfo when in a fight etc.  (Done?  Well, in a nonefficient way.)
# Fix /examine etc
# Make sure various notification types work



# /searchmall does something really weird with focus (FF BUG!)
# switching to an inactive tab, scrolling can get weird

# MINOR
#	PREF: Whether to autoswitch to channel when sent message indicates it
# 	PREF: Keyboard shortcuts



### 
	Up here go all the helper functions
###

#Object for abstracting messaging a little


logit = (msg)=>console.log("~kd: #{msg}")
logit("------------HELLO FROM KD.COFFEE! ------------")

#Test because this failed once!
xhr = new XMLHttpRequest();


class Port
	constructor: ()->
	emit: (msg, data)=>
		self.port.emit(msg, data)
	on: (msg, callback)=>
		self.port.on(msg, callback)

# Pretend direct connection?
class DirectPort
	link: null
	emit: (msg, data) => 
		if @link
			@link.trigger(msg, data)
		else
			this.trigger(msg, data)
	on: (msg, callback) => @listeners[msg] = callback
	listeners: []
	trigger: (msg, data) =>
		if @listeners[msg]?
			@listeners[msg](data)



window.globalPort = new DirectPort()


try
	host = window.location.host
	logit("Host is #{host}")
catch e
	logit("#{e}")

if host.match("localhost")?
	predicate = "http://" + host
else
	predicate = "http://" + host
makeURL = (location) -> predicate + "/" + location

# menu: 0 charpane:1 mainpane:2 chat:3
if not proxy
	frame = (key)=> window.frames[key]
else
	frame = (key)=> parent.window.frames[key]

getChatDoc = () => 
	try
		frame(3).document
	catch e
		logit("dumb error: #{e}")
getMainDoc = () => frame(2).document


# Replacement for that weird Kol custom function
URLEncode = (plaintext) => window.encodeURIComponent(plaintext)


#Definitions to replace KoL's own shortcuts
#window.top.charpane = frame(1)
#window.top.mainpane = frame(2)
#Somtimes the jax code calls inv_update() -- should maybe define that function as well



class Prefs
	prefs: []
	constructor: ()->
		for name, val of defaultPrefs
			@prefs[name] = val
	#	porter.on("setPrefs", @setPrefs)
	setPrefs: (payload) =>
		oldPrefs = @prefs
		@prefs = payload.prefs
		logit(oldPrefs.toSource() )
		try 
			for p of oldPrefs
				if oldPrefs[p]!=@prefs[p] then @onPrefChange(p)
		catch e
			logit("Error #{e}")

	@onPrefChange: ()=> #Nothing needed here for now


class MainFrame
	session: null
	constructor: (@session) ->
	loadLink: (payload)=>
		return if payload is null
		path=payload.path
		if path.indexOf('http://')<0 and path.indexOf('https://') < 0
			path=@session.makeURL(path)
		logit(path)
		frame(2).location.href=path
	
	

class Jax
	session: []
	text: ""
	constructor: (kolsession, line)->
		@session= kolsession
		@text = line


	handleJaxResponse: (out) =>
		logit("JAX RESPONSE\n____________________")

		# Much of this is just following what KoL does directly
		try
			logit(out)
			$eff = $(getMainDoc() ).find("#effdiv")
			if $eff.length is 0
				div = getMainDoc().createElement('DIV')
				div.id = 'effdiv'
				# By default, insert into the body, but then if there's a content div get that as the 'body' instead.
				body = getMainDoc().body
				if $('#content_').length > 0 then body = $('#content_ div:first')[0]
				body.insertBefore(div, body.firstChild);
				$eff = $(div)
			$eff.find('a[name="effdivtop"]').remove().end()
				.prepend('<a name="effdivtop"></a><center>' + out + '</center>').css('display','block');
		catch e
			logit(e)
		#refresh chat pane
		frame(1).location.href = @session.makeURL('charpane.php')



	run: ()=>
		logit("Running jax request! -----")
		re1 = /dojax\('(.*?)'\);?\)/g
		re2 = /dojax\('(.*?)'\);?\)/
		handlerFactory = (path)=>
			return () => @session.kolGet(path).then( @handleJaxResponse )
		dojaxList=@text.match(re1)
		if(dojaxList?)
			for jax, i in dojaxList
				addr = jax.match(re2)[1]
				
				#Sad that ~let~ doesn't work in CS :(
				#Use handlerFactory to bind the value instead
				logit(addr)
				window.setTimeout( handlerFactory(addr),i*100)
		
		reJs1 = /js\((.*?)\)-->/g
		reJs2 = /js\((.*?)\)-->/
		jsList = @text.match(reJs1)
		if( jsList? )
			for js, i in jsList
				if js.match('dojax') is null
					jsFragment = js.match(reJs2)[1]
					logit("jsFrament is #{jsFragment}")
					eval(jsFragment)
	
	
	
	
	
class PlayerDaemon
	session: []
	realNames: new Object()
	constructor: (@session) ->
	pids: {"AFHk":1736457, "AFH":1736451, "AFHobo":1736458}
	headers: []

	showPlayer: (id) => frame(2).location.href= @session.makeURL("showplayer.php?who=#{id}")


	# To be used inside $.when()	
	getPlayerId: (name)=>
		return @pids[name] if @pids[name]?
		return @session.kolGet("submitnewchat.php?j=1&	graf=/whois #{name}")
			.success( (result) => @pids[name]=result.match(/#(\d+)/)[1] if result.match(/#(\d+)/) != null )
			
	loadPlayer: (payload)=> 
		name=payload.name
		action = payload.name
		logit("***\n\nTrying to show #{name}\n\n***")
		$.when( @getPlayerId(name) )
			.then( ()=> @showPlayer(@pids[name]) )	

	doPlayerAction: (payload)=> 
		console.log("DoPlayerAction: #{payload.toSource()}")
		name=payload.name
		logit("***\n\nTrying to do player action for: #{name}\n\n***")
		$.when( @getPlayerId(name) )
			.then( ()=> frame(2).location.href= @session.makeURL("#{payload.action}=#{@pids[name]}") )	


	parsePlayerSheet: (result) =>
		busymatch = /action=fight\.php|choice\.php/
	
		if result.match(busymatch)?
			logit( result.match(busymatch))
			logit( result.match(busymatch)?)
			logit("\t!!!\nTotally in a fight/choice page, bailing\n\n")
			return null

		logit("Parsing player sheet...")
		$sheet = $(result)
		avatar = $("img", $sheet).first().attr('src')
		info = $("img", $sheet).first().parent().next().children('center').html()
		#The last listed clan link is the current clan
		clan = $("""[href*="showclan.php"]""", $sheet).last().text()
		# Deal with astral spirits.  Stupid astral spirits.
		if not info?
			info = $("img", $sheet).first().parent().next().html()
		logit("found info #{info.toSource()}")		
		return {"avatar":avatar, "info":info, "clan":clan}

	getPlayerHeader: (name) =>				
		#payload.name
		defer = $.Deferred()
		getSheet = (id)=> 
			@session.kolGet("showplayer.php?who=#{id}")
				.success( (result, status, request)=> 
					@findPlayer(name).header = @parsePlayerSheet(result)
					logit("TRYING TO RESOLVE DEFERRED 1")
					
					defer.resolve()
				 )
		$.when( @getPlayerId(name) )
			.then( ()=> getSheet(@pids[name]) )
		return defer.promise()

		

	findPlayerStatus: (payload) =>
		logit("\nFinding player status -8-8-")

		name = payload.name
		logit(payload)
		@getPlayerChatStatus(name)

	
	getPlayerChatStatus: (name)=>
		@session.kolGet("submitnewchat.php?j=1&graf=/whois #{name}") 
			.then( (data)=> @findPlayer(name).status = @parsePlayerChatStatus(data)  ) 

	parsePlayerChatStatus: (data)=>
		logit(data)
		if data.match("This player is currently away")?
			status = "away"
		else if data.match("This player is currently online")
			status = "online"
		else
			status = "offline"
		logit("\nStatus is #{status} \n\t8-8-8\n")
		return status

	getAllPlayerInfo: (name) =>
		defer = $.Deferred()
		$.when(@getPlayerId(name)).then(
			()=> 
				@findPlayer(name).id = @pids[name]
				logit("--- found id ---")
				$.when(@getPlayerChatStatus(name), @getPlayerHeader(name) )
					.then( ()=> defer.resolve()  )
		)
		return defer.promise()

	findPlayer: (name)=>
		name = @normalizeName(name)
		if not @playerInfo[name]?
			@playerInfo[name]=new Object()
			@playerInfo[name].name = name
		return @playerInfo[name]

	normalizeName: (name) => name.toLowerCase()

	watchPlayer: (name) => 
		#TODO fix to check properly, as an array entry not object key
		if not @playersToWatch[@normalizeName(name)]?
			@playersToWatch.push(@normalizeName(name))

	requestPlayerInfo: (payload) =>
		name = payload.name
		@watchPlayer(name)
		@getAllPlayerInfo(name).then( ()=> @broadcastPlayerInfo(name) )
		
	getAllPlayers: ()=>
		handlerFactory = (name)=> return ()=>@broadcastPlayerInfo(name)
		for name in @playersToWatch
			@getAllPlayerInfo(name).then( handlerFactory(name)  )

	broadcastPlayerInfo: (name)=>
		logit("BROADCASTING PLAYER INFO")
		porter.emit("setPlayerInfo", @playerInfo[name])


	watchLoop: () =>
		logit("\n\n\n !!!!!!   !!!!!!!  \n Watch loop running!  #{@active}  \n\n\n")
		if not @active then return
		try
			@getAllPlayers()
		catch e
			logit('Error ' +e)
		window.setTimeout( @watchLoop, 30000) 

	start: () =>
		@active = true
		@watchPlayer( @session.status.name )
		@watchLoop()

	stop: () =>	@active = false

	active: false
	playerInfo: []
	playersToWatch: []




class Chatter
	chatDelay: 3000	#Default delay set by kol
	lastseen:  0
	active: false
	session: null
	pd: null
	openChannel: null

	constructor: (@session) ->
		

	getNewChat: ()=>
		return @session.kolGetJson("newchatmessages.php?j=1")
	
	parseChannel: (response)=>
		matched = response.match(/You are now talking in channel: (.+?)\./)
		@openChannel = matched[1] if matched? 
		return matched?


	getOpenChannel: =>
		return @session.kolGet("submitnewchat.php?graf=/c")
				.fail( (failure )=> logit("FAILURE on openchannel #{failure}"))
				.success( ()->logit('stage 1 finished') )
				.success( @parseChannel )
				.success( ()->logit('stage 2 finished') )
	
	getPlayerMenuOptions: =>
		@session.kolGet("mchat.php").then(
			(result)=>
				menuPattern = /actions\s*\=\s*({.+?});/
				menuMatch = result.match(menuPattern)
				#logit("\nMenu match\n#{menuMatch[1]}")
				window.actions = @menuJSON = JSON.parse(menuMatch[1])
				logit("Menu match:\n #{@menuJSON.toSource()}")
		)

	# One day, let these be edited
	registeredChatBots: ["AFHk", "AFH", "AFHobo"]

	isChatBot: (name)=> 
		return true for bot in @registeredChatBots when name is bot
		return false

	makePlayerUrl: (id) => 'showplayer.php?who=#{id}'

	

	handleChatBot: (msg) =>
		try
			# Attempt to deal with chatbots
			nameMatch = msg.msg.match(/[\[\(\{](.+?)[\]\)\}]/)
			if nameMatch?
				bot = msg.who
				displayName = nameMatch[0]
				alias = nameMatch[1] 
				msg.msg = msg.msg.replace(displayName, '')

				#Remove spaces introduced by chat backend.  No one has names of length>40, right?
				# TODO this isn't quite airtight, there are corner cases, but those hypothetical people suck :P
				if alias.length>20 and alias.substr(19,1) is ' '				
					alias = alias.substr(0, 19) + alias.substr(20)
					displayName = displayName.substr(0, 20) + displayName.substr(21)
			else
				alias = displayName = msg.who.name
		catch e
			logit(e)

		logit("\nDealing with chatbot for #{displayName}\n")
		if @session.pd.pids[alias]?
			msg.who.id = @session.pd.pids[alias]
		else
			msg.who.id = '???'
			$.when( @session.pd.getPlayerId("#{alias}")).then(
				()=> porter.emit('setSpeakerId', {'name':alias, id:@session.pd.pids[alias]})
			)

		# handle emotes.  Grr.
		if msg.type is 'public' and msg.format is '1' 
			$emote = $("<div>#{msg.msg}</div>")
			$link = $("""<i><a pname='#{alias}'	 href='showplayer.php?who=#{msg.who.id}'<font color='black'>#{alias}</font></a></i>""")
			$("a", $emote).first().replaceWith($link)	
			msg.msg=$emote.html()
		msg.who.name = alias
		msg.who.displayName = displayName
		logit("Displayname is #{displayName}")
		logit("Returning chatbot message #{msg.toSource()}")
		return msg



	processChatLine: (msg, context)=>
		#newType = msg.type
		if not msg.channel?
			msg.channel = '!!current'

		# These deal with kolproxy's treatment of the special channels.
		if msg.channel is 'clan PRIVATE:'
			msg.channel = 'private'
		if msg.channel is 'clan OFFTOPIC:'
			msg.channel = 'offtopic'

		if not msg.msg?
			return
		###
		Need to do the following things with msg data

		* Flag whether the message was actively requested, and thus should initiate a tab switch
		###
		try
			if msg.type is 'public' and msg.who?
				prvPattern = /^\s*?private:/i
				offPattern = /^\s*?offtopic:/i
				#Do appropriate substitution for private messages
				if msg.channel is 'clan' and msg.msg.match( prvPattern)
					logit("\n\n private channel attempt")
					msg.msg = msg.msg.replace(prvPattern, "")
					msg.channel = "private"
				else if msg.channel is 'clan' and msg.msg.match(offPattern)
					msg.msg = msg.msg.replace(offPattern, "")
					msg.channel = "offtopic"

				#Reroute pvp announcements if necessary
				if prefs.prefs.splitPvP is true and ( (msg.who.id is '-69') or (msg.who.id is '-43') ) and msg.channel is "pvp"
					msg.channel = "pvp_radio"
					msg.tabName = "pvp/radio"
				if @isChatBot(msg.who.name)
					msg = @handleChatBot(msg)

			if msg.type is 'private'
				if msg.for?
					msg.channel =  msg.for.id
					msg.tabName = msg.for.name
				else
					msg.channel = msg.who.id
					msg.tabName = msg.who.name
			else if not msg.tabName?
				msg.tabName = msg.channel

			tlcName = @session.status.name.toLowerCase()
			if msg.type is 'public' and msg.msg?.toLowerCase().match(tlcName)? and (tlcName isnt msg.who?.name.toLowerCase())
				msg.important = true
			if msg.type is 'public' and prefs.prefs.watchWords.length>0 and msg.msg?.match(prefs.prefs.watchWords)?
				msg.important = true


			date = new Date()
			msg.timestamp = date.getTime();
			logit('initial timestamp: ' + msg.timestamp)
			#logit("__________________Recieved message: \n#{msg.toSource()}\n=============")
		catch e 
			logit("Error #{e} ... ")



		#logit("About to emit chat message, to tab [#{chatPayload.tab}]")
		porter.emit("newChatMessage", msg)

		
	chatWindow: (tag) =>  $("#clan", getChatDoc()  )

	processChatResponse: (response)=>
		#logit("Checking chat response")
		#Bail if login page is returned, and stop chat from running.
		#if response.match('<a href="createplayer.php">Create an Account</a>')?
		#	alert( 'You were logged out of this session!')
		#	@stop()
		#	return

		#logit("Processing chat response")
		logit("Raw chat response is: \n\n #{response.toSource() }  \n\n")

		#	Process output
		if response.output?
				@processOutput(response.output, response)

		
		for msg in response.msgs
			@processChatLine(msg, response)
	
		
	processOutput: (output, context)=>
		logit("Output was: #{output}")
		if output.length<1 then return
		if output?.match(/<!--js\(/)?	
				dojax = new Jax(@session, output)
				dojax.run()
		oMsg = 
			msg: output
			type: 'output'
			channel: "!!current"
		@processChatLine(oMsg, context)


	processChatError: (error) => logit("-----\nChat error!\n#{error.toSource()}\n-----")

	chatLoop: =>
		logit("\nChat loop #{@active}...\n")
		return if @active == false
		@getNewChat()
			.success( @processChatResponse )
			.fail(  @processChatError )
			.complete( => window.setTimeout( @chatLoop, @chatDelay)  )

	sendChatMessage: (chatMessage)=>
		#logit("submitting chat message #{msg}")
		msg = chatMessage.msg
		tab = chatMessage.currentTab
		logit("=========================")
		logit("Submitting message:")
		logit("tab is #{tab}")

		# Target message at the correct place  TODO fix wonky private system
		if msg.substring(0,4) is '/em ' or  msg.substring(0,4) is '/me '
			emote = '/em '
			msg = msg.substring(4)	
		else 
			emote= ''

		if msg[0] isnt '/' 
			if tab.type isnt 'private'
				if tab.id is 'private'
					msg = "/clan PRIVATE: #{emote}#{msg}"
				else if tab.id is 'offtopic'
					msg = "/clan OFFTOPIC: #{emote}#{msg}"
				else if tab.id is 'pvp_radio'
					msg = "/pvp #{emote}#{msg}"
				else
					msg = "/#{tab.id} #{emote}#{msg}" 
			else
				target = tab.name.replace(' ', '_')
				msg = "/msg #{target} " + msg
		if msg.match(/^\/who\s*?$/)? and (tab.type isnt 'private')
			msg =  "/who #{tab.id}"
		
		
		logit("message is: #{msg}")
		logit("^^^^^^^^^^^^^^^^^^^^^^^^^^")
		encoded_msg = URLEncode(msg)
		return @session.kolGetJson("submitnewchat.php?graf=#{encoded_msg}&j=1")
			.success( @processChatResponse )
			.success(
				()=>@getNewChat()
						.success( @processChatResponse )
						.fail(  @processChatError )
			)
			.fail(  @processChatError )
		





	start: =>
		logit('Starting')
		@active=true
		porter.on("newChatSubmission", @sendChatMessage)
		
		try
			porter.on("loadLink",  @session.mf.loadLink)
			porter.on("loadPlayer", @session.pd.loadPlayer)
			porter.on("requestPlayerInfo", @session.pd.requestPlayerInfo)
			#Special testing channel
			porter.on("testChatMessage", @processChatLine)
			porter.on("doPlayerAction", @session.pd.doPlayerAction)
			#porter.on("requestPlayerHeader", @session.pd.findPlayerHeader )
			#porter.on("requestPlayerStatus", @session.pd.findPlayerStatus )
			#porter.on("")

		catch e
			logit("error #{e}")
		
		try
			logit("-open channel-")
			$.when(@getPlayerMenuOptions(), @getOpenChannel())
				.fail( (failure )=> logit("FAILURE #{failure}"))
				.then( ()=>porter.emit("chatDisplayInitData", {'openChannel':@openChannel, 'playername':@session.status.name, 'menu':@menuJSON})
				).then( @chatLoop )
			#@chatLoop()
		catch e
			logit(e)


	stop: => @active = false

		

class KolSession
	active: false
	status: null
	makeURL: (path) => makeURL(path)

	start: ->
		logit("Starting session")
		return @getStatus().then ()=>@active=true

	getStatus:  => 
		url =  @makeURL("api.php?what=status&for=KolDaemon")
		logit('json url is ' + url)
		return $.getJSON(url)
			.fail( (failure )=> logit("Json FAILURE #{JSON.stringify(failure)}"))
			.done( (data)=> logit("BACK") )
			.done( (data, text)=> logit(text))
			.done( (data, text, jqx)=> logit(jqx.responseText) )
			.done( (data, text, jqx) => @status = JSON.parse(jqx.responseText))
	kolGet: (location) =>
		logit("Attempting to get #{location}")
		if location.indexOf("#{@status.pwd}") < 0 
			if location.indexOf('?') < 0 
				location+='?'
			else
				location+='&'
			location+="pwd=#{@status.pwd}&name=#{@status.name}"

		url = @makeURL(location)
		#logit("get url is: #{url}")
		return $.ajax({"url":url, dataType:"html" } )

	kolGetJson: (location) =>
		logit("Getting #{location}")
		
		if location.indexOf("#{@status.pwd}") < 0 
			if location.indexOf('?') < 0 
				location+='?'
			else
				location+='&'
			location+="pwd=#{@status.pwd}&name=#{@status.name}"
		
		url = @makeURL(location)
		#logit("URL is #{url}")
		return( $.getJSON(url) )




session = new KolSession()
session.pd = new PlayerDaemon(session)
session.chat = new Chatter(session)
session.mf = new MainFrame(session)
#porter = new Port()
porter = window.globalPort

window.globalPrefs = prefs = new Prefs()
porter.on("setPrefs", prefs.setPrefs)


init = ()->
	logit("Reached init()")
	session
		.start()
		.done( session.chat.start )
		.done( session.pd.start )

#wait until chat display is ready to start things up?
porter.on("chatDisplayReady", init )






# porter = new DirectPort()
# window.['charpane'].porter = new DirectPort()
# porter.link = window['charpane'].porter
# window['charpane'].porter.link = porter




		


