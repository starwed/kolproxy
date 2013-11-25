add_printer("/aux.css", function()
  text = [[

		
		.ui-corner-all, .ui-corner-bottom, .ui-corner-right, .ui-corner-br{
			border-bottom-right-radius: 0px;
		}

		.ui-corner-all, .ui-corner-bottom, .ui-corner-left, .ui-corner-bl{
			border-bottom-left-radius: 0px;
		}

		.ui-corner-all, .ui-corner-top, .ui-corner-left, .ui-corner-tl {
			border-top-left-radius: 0px;
		}

		.ui-corner-all, .ui-corner-top, .ui-corner-right, .ui-corner-tr {
			border-top-right-radius: 0px;
		}


		.infoPadder{
				z-index: -1;
			
		}

		.option-text{
			font-weight: 400;
			margin-left: 1em;
			margin-right: 1em;
		}

		.clanHeader{
			padding: 5px;
		}

		.chatOpt a{
			font-size: smaller;
			text-decoration: underline ! important;
			margin-left: 0.5em;
			letter-spacing: 0.4pt;			
			color: grey;
		}

		.timestamp{
			display: none;
			font-size: 9px;
			vertical-align: middle;
		}


		.chatInfo{
			/*position: absolute;*/
			padding-left: 5px;
			font-size: smaller;
			width: 100%;
			z-index: 5;
			background-color: white;
		}

		.chatInfo table{
			padding-right: 15px;
		}

		.clanInfo{
			text-align: right;

		}
		.clanInfo b{
			margin-right: 10px;
			text-align: right;
			font-weight: 100 ! important;
			letter-spacing: 1.5pt;
			word-spacing: 1pt;
			color: grey;
			font-style: italic;

		}
		.chatInfo a{
			font-size: 12px;
			cursor: pointer;
		}


		.chatPadder{
			height: 45px;
		}

		hr {
			width: 80%;
			height: 1px;
			border: 1px solid lightgrey;
			margin-top: 2px;
			margin-bottom: 2px;

		}

		html, body { 
			height: 100%; 
			overflow: hidden;
			width: 100%;
			padding-left: 2px;
			padding-right: 2px;

		 }
		 
		 html{
		 	font-size: 65%;

		 }


		div.boxmsg.output {
			background-color: #EEFFEE;
			box-shadow: 0px 0px 2px green inset;			
		}
		div.boxmsg.system {
			background-color: #FFEEEE;
			box-shadow: 0px 0px 2px red inset;			
		}
		div.boxmsg.event {
			background-color: #EEEEFF;
			box-shadow: 0px 0px 2px blue inset;			
		}



		 div.boxmsg {
		 	/*0px 0px 1px green inset*/
		 	position: relative;
		 	
		 	
		 	/*background-color: rgb(251, 249, 238);*/
		 	
		 	/* These should add to 15px*/
		 	margin-bottom: 5px;
		 	padding-top: 3px;
		 	padding-bottom: 3px;
		 	margin-top: 4px;

		 	padding-right: 12px;
		 	padding-left: 12px;
		 	text-indent: -5px;		 	
		 	

		 	/*border: 1px solid #339933;
		 	margin-left: 2px;
		 	margin-right: 2px;
		 	padding-left: 10px;
		 	padding-right: 3%;
		 	border-radius: 5px;
		 	width: -moz-calc(93%-5px);*/

		 	overflow: hidden;
		 	

		 	font-size: 12px;
		 	line-height: 15px;

		 	text-indent: -5px;

		 }


		.boxmsg .ui-icon-close{
			 	position: absolute;
			 	top: -1px;
			 	right: 0px;
				opacity: 0.5;
				cursor: pointer;
		 
		}


		.boxmsg .ui-icon-close:hover {
			 	opacity: 1.0;
 	
		}


		 td, table{
		 	word-wrap:break-word;
		 	font-size: inherit;
		 }


		 ul, ol, li, h1, h2, h3, h4, h5, h6, pre, form, body, html, p, blockquote, fieldset, input
		{ margin:0px; padding:0px }

		a.itemlink {
			color: blue !important;
			text-decoration: underline !important;
		}

		a {
			text-decoration: none;
			cursor: pointer;
		}

		#tabs{
			border: none ! important;
			margin: 0 ! important;
			padding: 0 ! important;
			height: 100%; 				
		}

		.chatTab{
			padding: 0 ! important;
			margin: 0 ! important;
			height: 100%;
		}
		#tab-head{
			font-size: 10px	;
			padding-top: 0 ! important;
			font-family: Helvetica;
			letter-spacing: 0.2pt;
		}

	

		#tab-head li.important{
			
			/*font-weight: bold;*/
		}



		.ChatWindow{
			z-index: 10;
			position: relative;
			top: 0px;


			border: 0px solid black;
			border-top: none;
			padding-left: 0px ! important;
			padding-right: 0px ! important;
			padding-top: 0px ! important;
			padding-bottom: 0px ! important;

			
			font-family: Helvetica, Arial, sans-serif;
	 		font-size: 12px;
	 		line-height: 15px;
	 		word-spacing: -1px;
	 		letter-spacing: 0.1pt;


			width: -moz-calc(100%);
			/*height: 100%;*/

			overflow-y: scroll; 
			overflow-x: hidden; 
			overflow: auto;

		}



		.chatWindow b{
			font-weight: 600 ! important;

		}

		a.player{
			font-weight: 600 ! important;
			
		}

		b{
			font-weight: 600 ! important;
		}

		.important{
			color: black;
			text-shadow: 0px 0px 3px Yellow
		}

		.loud {
			border: 1px solid red;
			box-shadow: 0px 0px 2px cyan inset ;
		}

		.talking{
			position: relative;
			
			text-indent:  -5px;
			
			padding-right: 5px;
			
			padding-left: 12px;
			margin-top: 0px;

			width: -moz-calc(100% - 17px );
		}

		a.speaker{
			cursor: pointer;
		}

		#tab-wrapper{
			height: 80%;
		}

		#outer-wrapper{ 
			width: 100%; 
			left: 0em;
			height: 100%;  
			padding: 0em;
			margin: 0;
			
		}

		#bottom-wrapper{
			position: relative;
			height: 3.3em;
			left: 0;
			background-color: transparent;
			width: 95%;

		}

		.TextInput{
			position: absolute;
			bottom: 10%;
			left: 1%;
			right: 5%;
			top: 20%;
			height: 70%;
			width: 94%;
			border: 1px solid black;
			font-size: 110%;
		}
	

		#gear{
			position: absolute;
			left: 96%;
			top: 22%;
			opacity: 0.5;
			cursor: pointer;
		}

		#gear:hover{
			opacity: 1.0;
		}

		#tabs li .ui-icon-close {
			 float: left; margin: 1px 0 0 -10px; cursor: pointer;
			 display: none;
				 
		 }

		 #tabs li.ui-tabs-selected .ui-icon-close:hover {
		 	
		 	opacity: 1.0;
		 }

		#tabs li.ui-tabs-selected .ui-icon-close {
			display: inline;
			opacity: 0.5;
		}



		 #tabs li.important .ui-icon-comment {
			 display: inline ! important;
				 
		 }


		 #tabs li .ui-icon-comment {
			 float: left; margin: 1px 0 0 -10px; cursor: pointer;
			 opacity: 0.6;
			 display: none;
				 
		 }


		 .status.online{
		 	color: green;
		 }

		 .status.offline{
		 	color: red;
		 }
		 .status.away{
		 	color: grey;
		 }

		 /* Kol context menus */
		 
		 div.rcm {
		        	position: absolute;
		        	font-family: Helvetica, Arial, sans-serif;
		        	font-size: 10pt;
		        	border: 1px solid black;
		        	background-color: #fff;
		        	display: none;
					z-index: 99;
		}
		
		p.rcm {
	        	cursor: pointer;
	        	background-color: white;
	        	margin: 0px;
	        	padding: 0px 2px;
		}
		
		p.rcm:hover {
	        	background-color: #ccccff;
		}
]]  
end )