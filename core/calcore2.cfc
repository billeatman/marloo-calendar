<cfcomponent displayname="service" output="false">

   <!--- get event listing in JSON format --->
   <cffunction name="gEvents" returntype="any" access="remote" returnFormat="json" output="false" hint="returns calendar events as JSON">
		<cfargument name="calID" type="numeric" required="false">
        <cfargument name="groupDays" type="boolean" required="false" default="true">
		<cfargument name="category" type="string" required="false" default="" hint="Can be a single string category name">
        <cfargument name="catID" type="string" required="false" default="" hint="Can be a single category ID or a list of category IDs">
        <cfargument name="featured" type="boolean" required="false" default="true" hint="show only homepage flagged events">
		<cfargument name="from" type="date" required="false" default="#now()#" hint="starting date for event listing">
        <cfargument name="to" type="date" required="false" hint="ending date for event listing, overrides limit">
        <cfargument name="nearestDay" type="boolean" required="false" default="false" hint="pulls in number of results to the nearest day">   
        <cfargument name="expandRepeaters" type="boolean" required="false" default="true">
        <cfargument name="expandSpans" type="boolean" required="false" default="true">
        <cfargument name="details" type="boolean" required="false" default="false">
        <cfargument name="keywords" type="string" required="false">

		<cfset var LOCAL = structNew()>

        <cftry>
        <!--- generate an argument hash --->
		<cfinvoke component="#application.calcache#" method="generateHash" argumentcollection="#arguments#" returnvariable="LOCAL.argHash">
        
        <!--- check the cache --->
        <cfinvoke component="#application.calcache#" method="checkCache" returnvariable="LOCAL.cacheData">
        	<cfinvokeargument name="from" value="#arguments.from#">
        	<cfinvokeargument name="hash" value="#LOCAL.argHash#">
        </cfinvoke> 
 
        <cfif LOCAL.cacheData NEQ false>
			<!--- Cache Hit! ---> 
			<cfset LOCAL.events = deserializeJSON(LOCAL.cacheData)>
		<cfelse>
 			<cfset LOCAL.events = arrayNew(1)>
                        
			<!--- bounds check our limit --->
            <cfif not isdefined("arguments.calId")>
            	<cfinvoke component="#application.calcore#" method="numericBoundsCheck" returnvariable="arguments.limit">
                	<cfinvokeargument name="num" value="#arguments.limit#">
                    <cfinvokeargument name="min" value="1">
                    <cfinvokeargument name="max" value="250">
                    <cfinvokeargument name="forceInt" value="true">
                </cfinvoke>         
            </cfif>

            <cfif arguments.details EQ true>
              	<cfset LOCAL.attributes = "calDesc,calContact,calPhone,calemail">
            <cfelse>
              	<cfset LOCAL.attributes = "">
            </cfif>

			<!--- get our events query --->        
            <cfinvoke component="#application.calcore#" method="getEvents" returnvariable="LOCAL.qEvents">
  				<cfif isDefined("arguments.calID")>
                   	<cfinvokeargument name="calID" value="#arguments.calID#">
  				</cfif>
            	<cfif isDefined("arguments.to")>
  					<cfinvokeargument name="to" value="#arguments.to#">
  				</cfif>
                <cfinvokeargument name="limit" value="10">
  				<cfinvokeargument name="category" value="#arguments.category#">
  				<cfinvokeargument name="catID" value="#arguments.catID#">
  				<cfinvokeargument name="featured" value="#arguments.featured#">
  				<cfinvokeargument name="from" value="#arguments.from#"> 
                <cfinvokeargument name="nearestDay" value="#arguments.nearestDay#">
  				<cfinvokeargument name="expandRepeaters" value="#arguments.expandRepeaters#">
  				<cfinvokeargument name="expandSpans" value="#arguments.expandSpans#">
				<cfinvokeargument name="attributes" value="#LOCAL.attributes#">
                <cfif isDefined("arguments.keywords")>
                    <cfinvokeargument name="keywords" value="#arguments.keywords#">
                </cfif>
         	</cfinvoke>	

			<cfset LOCAL.retID = 0>
            <cfloop query="LOCAL.qEvents">
            	<!--- build structure for calendar event --->
                <cfset LOCAL.event = structNew()>
                <cfset LOCAL.event.calid = LOCAL.qEvents.calid >
                <cfset LOCAL.event.day = DateFormat(LOCAL.qEvents.groupedstartdate, 'd') >
                <cfset LOCAL.event.month = DateFormat(LOCAL.qEvents.groupedstartdate, 'm') >
                <cfset LOCAL.event.year = DateFormat(LOCAL.qEvents.groupedstartdate, 'yyyy') >
                
                <cfset LOCAL.event.location = "#trim(LOCAL.qEvents.calPlace)#">
                <cfset LOCAL.event.description = "#trim(LOCAL.qEvents.calEvent)#">
                <cfset LOCAL.event.calcategory = "#trim(LOCAL.qEvents.calcategory)#">               	

               <cfif arguments.details EQ true>
                    <cfset LOCAL.event.calDesc = "#trim(LOCAL.qEvents.calDesc)#"> 
                    <cfset LOCAL.event.calContact = "#trim(LOCAL.qEvents.calContact)#"> 
                    <cfset LOCAL.event.calPhone = "#trim(LOCAL.qEvents.calPhone)#"> 
                    <cfset LOCAL.event.calEmail = "#trim(LOCAL.qEvents.calEmail)#"> 

                    <cfscript>
                    
                    LOCAL.cfjsoup = new assets.cfjsoup.cfjsoup();
                    LOCAL.Whitelist = cfjsoup.GetWhitelist().basic();
                    LOCAL.Whitelist.removeTags("span");

                    LOCAL.event.calDesc = cfjsoup.clean(LOCAL.event.calDesc, LOCAL.Whitelist);

                    </cfscript>

                    <cfset LOCAL.event.calDesc = trim(LOCAL.event.calDesc)>

                    <cfif mid(LOCAL.event.calDesc, 1, 6) EQ "&nbsp;">
                        <cfset LOCAL.event.calDesc = mid(LOCAL.event.calDesc, 7, len(LOCAL.event.calDesc) - 6)>
                    </cfif>

                    <!--- filter out tabs and carriage returns that jsoup adds --->
                    <cfset LOCAL.event.calDesc = replaceNoCase(LOCAL.event.calDesc, chr(10), "", 'all')>
                    <cfset LOCAL.event.calDesc = replaceNoCase(LOCAL.event.calDesc, chr(9), "", 'all')>

                    <!--- filter h1, h2, h3 to strong --->
                    <cfset LOCAL.event.calDesc = replaceNoCase(LOCAL.event.calDesc, "h1>", "strong>", 'all')>
                    <cfset LOCAL.event.calDesc = replaceNoCase(LOCAL.event.calDesc, "h2>", "strong>", 'all')>
                    <cfset LOCAL.event.calDesc = replaceNoCase(LOCAL.event.calDesc, "h3>", "strong>", 'all')>
                    
                    <!--- filter empty paragraphs --->
                    <cfset LOCAL.event.calDesc = replaceNoCase(LOCAL.event.calDesc, "<p><br></p>", "", 'all')>
                </cfif>

                <cfinvoke component="#application.calcore#" method="formatDateTime" returnvariable="LOCAL.eTime">
                	<cfinvokeargument name="startDate" value="#LOCAL.qEvents.Startdate#">
                    <cfinvokeargument name="endDate" value="#LOCAL.qEvents.Enddate#">
                    <cfinvokeargument name="allDay" value="#LOCAL.qEvents.allDay#">
                    <cfinvokeargument name="groupDays" value="#true#">
                    <cfinvokeargument name="timeMask" value="h:mmt">
                </cfinvoke>

                <cfset LOCAL.event.time = LOCAL.eTime>
    
                <!--- set the return ID --->	
                <cfset LOCAL.retID = LOCAL.retID + 1>
                <cfset LOCAL.event.id = LOCAL.retID>
                                
                <cfset arrayAppend(LOCAL.events, LOCAL.event)>
          	</cfloop>

            <cfset testEvents = serializeJSON(LOCAL.events)>
            <cfset testEvents = replaceNoCase(testEvents, "\n", "", 'all')>
      	
            <!--- get the next event end timestamp after the from argument --->
            <cfinvoke component="#application.calcore#" method="getNextEndDate" returnvariable="LOCAL.nextEventDate">
	            <cfinvokeargument name="datetime" value="#arguments.from#">
                <cfinvokeargument name="qEvents" value="#LOCAL.qEvents#">
            </cfinvoke>

        	<cfinvoke component="#application.calcache#" method="cacheAdd">
            	<cfinvokeargument name="from" value="#arguments.from#">
                <cfinvokeargument name="nextEventDate" value="#LOCAL.nextEventDate#">
                <cfinvokeargument name="hash" value="#LOCAL.argHash#">
                <cfinvokeargument name="cacheData" value="#serializeJSON(LOCAL.events)#">
			</cfinvoke>               	
                       
        </cfif>
 		
        <cfcatch>    
        	<!--- log any errors --->
            <cfreturn "error">
        </cfcatch>
        </cftry>

        <cfreturn LOCAL.events>
   </cffunction> 
    
    <cffunction name="getCategories" returntype="any" access="remote" output="false" returnFormat="JSON" hint="get calendar categories as JSON">
        <cfset var LOCAL = structNew()>

		<cfinvoke component="#application.calcore#" method="getCategories" returnvariable="LOCAL.qCategories">
                
        <cfinvoke component="assets.queryToStruct" method="queryToStruct" returnvariable="LOCAL.retVal">
        	<cfinvokeargument name="query" value="#LOCAL.qCategories#">
        </cfinvoke>
        <cfreturn LOCAL.retVal>
    </cffunction>
    
    <cffunction name="getEvent" returntype="any" access="remote" output="true" returnFormat="JSON" hint="get event details as JSON">
    	<cfargument name="calId" required="true" type="numeric">
        <cfargument name="date" required="false" type="date">
        <cfargument name="eventAsText" required="false" type="boolean" default="false">
  
		<cfset var LOCAL = structNew()>
        <cfset LOCAL.attributes = "calDesc,calContact,calPhone,calEMail">

        <!--- get events query --->        
        <cfinvoke component="#application.calcore#" method="getEvents" returnvariable="LOCAL.qEvent">
          	<cfinvokeargument name="calID" value="#arguments.calID#">
            <cfinvokeargument name="groupDays" value="#true#">
            <cfinvokeargument name="limit" value="1">
 			<cfinvokeargument name="featured" value="false">
            <cfif isDefined("arguments.date")>
  				<cfinvokeargument name="from" value="#arguments.date#"> 
	  			<cfinvokeargument name="expandRepeaters" value="true">
            <cfelse>
	  			<cfinvokeargument name="expandRepeaters" value="false">
            </cfif>
            <cfinvokeargument name="nearestDay" value="false">
  			<cfinvokeargument name="expandSpans" value="false">
			<cfinvokeargument name="attributes" value="#LOCAL.attributes#">
        </cfinvoke>	
            
        <cfinvoke component="assets.queryToStruct" method="queryToStruct" returnvariable="LOCAL.oEvent">
        	<cfinvokeargument name="query" value="#LOCAL.qEvent#">
            <cfinvokeargument name="columnList" value="calid, startdate, enddate, calcontact, calevent, calemail, calcategory, caldesc, calplace, allday, calphone, calshow, groupedStartDate, groupedEndDate">
        </cfinvoke>
  
        <cfif arguments.eventAsText EQ true>
        	<cfinvoke component="assets.utilityCore" method="stripHTML" returnvariable="LOCAL.eventDesc">
            	<cfinvokeargument name="STR" value="#LOCAL.oEvent[1].CalDesc#">
            </cfinvoke>
       	<cfelse>
            <cfinvoke component="assets.utilityCore" method="stripHTMLTags" returnvariable="LOCAL.eventDesc">
            	<cfinvokeargument name="HTML" value="#LOCAL.oEvent[1].CalDesc#">
                <cfinvokeargument name="stripComments" value="true">
                <cfinvokeargument name="TagList" value="script,head,font,div,span">
            </cfinvoke>
		</cfif>
           
		<cfset LOCAL.oEvent[1].CalDesc = LOCAL.eventDesc>
 
        <cfinvoke component="#application.calcore#" method="formatDateTime" returnvariable="LOCAL.time">
        	<cfinvokeargument name="startDate" value="#LOCAL.oEvent[1].groupedStartDate#">
            <cfinvokeargument name="endDate" value="#LOCAL.oEvent[1].groupedEndDate#">
            <cfinvokeargument name="allDay" value="#LOCAL.oEvent[1].allDay#">
        	<cfinvokeargument name="groupDays" value="#true#">
        </cfinvoke>
        
        <cfif fix(LOCAL.oEvent[1].groupedStartDate) NEQ fix(LOCAL.oEvent[1].groupedEndDate)>
        	<cfset LOCAL.oEvent[1].displayDate = LOCAL.time>
            <cfset LOCAL.oEvent[1].displayTime = "">
        <cfelse>
        	<cfset LOCAL.oEvent[1].displayDate = Dateformat(LOCAL.oEvent[1].groupedStartDate, 'dddd, mmm dd yyyy')>
            <cfset LOCAL.oEvent[1].displayTime = LOCAL.time>
        </cfif>
  
  		<!--- later we might implement true dates using ISO date format, but for now no actual dates --->
        <cfset structDelete(LOCAL.oEvent[1], 'ENDDATE')>
        <cfset structDelete(LOCAL.oEvent[1], 'STARTDATE')>
        <cfset structDelete(LOCAL.oEvent[1], 'GROUPEDENDDATE')>
        <cfset structDelete(LOCAL.oEvent[1], 'GROUPEDSTARTDATE')>

        <cfreturn LOCAL.oEvent[1]>
    </cffunction>

</cfcomponent>
