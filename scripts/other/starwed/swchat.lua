
add_printer("/chatlaunch.php", function() 

	text = [[
<html>
	<head>
		<link rel="stylesheet" type="text/css" href="http://codeorigin.jquery.com/ui/1.8.24/themes/smoothness/jquery-ui.css"/>
		<link rel="stylesheet" type="text/css" href="aux.css" />

		<script src="http://images.kingdomofloathing.com/scripts/jquery-1.5.1.js"></script>
		<script src="http://codeorigin.jquery.com/ui/1.8.24/jquery-ui.js"></script>
		
		<script src="http://images.kingdomofloathing.com/scripts/window.js"></script>
		<script src="http://images.kingdomofloathing.com/scripts/rcm.20101215.js"></script>

		<script src="kd.js"> </script>
		<script src="chatDisplay.js"> </script>

	</head>
	<body>
		<div id="outer-wrapper">    
			<div id="tab-wrapper">    
				<div id="tabs" class="tabs-bottom">     
					<ul id="tab-head">  </ul> 
				</div>  
			</div>  
			<div id="bottom-wrapper">   
				<div id="InputForm">
					<center>       
						<input id="chatBox" class="TextInput"  maxlength="200" type="text" size="12" id="entry" autocomplete="off" />      
						<span id="gear" class="ui-icon ui-icon-gear">Options</span>    
					</center>
				</div>
			</div>
		</div>

		<div id="menu" class="rcm"></div>


	</body>
</html>

]] 
end)