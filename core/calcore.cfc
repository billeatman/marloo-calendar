<cfcomponent displayname="calcore" output="false">
   <!--- properties --->
   <cfset variables.datasource = '#application.datasource#'>
   <cfset variables.admin = false>
   
   <cffunction name="init" returntype="calcore">
   		<cfargument name="datasource" required="false" type="string" default="#variables.datasource#" hint="Calendar datasource">
   		<cfargument name="admin" required="false" type="boolean" default="#variables.admin#" hint="setting 'true' will return unapproved events">
        <cfset variables.datasource = arguments.datasource>
        <cfset variables.admin = arguments.admin>
   		<cfreturn this>
   </cffunction>
   
   <cffunction name="getNextEndDate" returntype="date" access="public" output="false" hint="Returns the next event time (can be an end or start date)">
   		<cfargument name="datetime" type="date" required="true">
        <cfargument name="qEvents" type="query" required="true">
   		<cfset var LOCAL = structNew()>

        <cfquery dbtype="query" name="LOCAL.qEEnd" maxrows="1">
        	select groupedEndDate 
            from arguments.qEvents
            where groupedEndDate > <cfqueryparam cfsqltype="cf_sql_timestamp" value="#arguments.datetime#">
            order by groupedEndDate asc
        </cfquery>    

        <cfif LOCAL.qEEnd.getRowCount() EQ 1>
        	<cfset LOCAL.eEnd = LOCAL.qEEnd.groupedEndDate[1]>
        <cfelse>
        	<cfset LOCAL.eEnd = arguments.datetime>
        </cfif>

      	<cfreturn LOCAL.eEnd>
   </cffunction>   
  
   <cffunction name="gEvent" returntype="query" access="public" output="false" hint="Main public function to retrieve events">
		<cfargument name="calID" type="numeric" required="false" default="-1">
        <cfargument name="limit" type="numeric" required="false" default="250" hint="number of results">
		<cfargument name="category" type="string" required="false" default="" hint="Can be a single string category name">
        <cfargument name="catID" type="string" required="false" default="" hint="Can be a single category ID or a list of category IDs">
        <cfargument name="featured" type="boolean" required="false" default="true" hint="true for featured / homepage events">
		<cfargument name="from" type="date" required="false" hint="starting date for event listing">
        <cfargument name="to" type="date" required="false" hint="ending date for event listing, overrides limit">
        <cfargument name="nearestDay" type="boolean" required="false" default="false" hint="pulls in number of results to the nearest day">
        <cfargument name="expandRepeaters" type="boolean" required="false" default="true">
        <cfargument name="expandSpans" type="boolean" required="false" default="true">
        <cfargument name="attributes" type="string" required="false">
        <cfargument name="keywords" type="string" required="false">

        <cfset var LOCAL = structNew()>
    
        <!--- set defaults for calID --->
		<cfif arguments.calID NEQ -1>
        	<cfif NOT isDefined("arguments.from")>
				<cfset arguments.from = createDate(1980,1,1)>
        	</cfif>
        <cfelse>
			<cfif NOT isDefined("arguments.from")>
                <cfset arguments.from = now()>
            </cfif>
        </cfif>
    
        <cfinvoke method="getRawData" argumentcollection="#arguments#" returnvariable="LOCAL.qEvents" />          
	
		<cfset LOCAL.qEventsInfo = getInfoFromQuery(qEvents: LOCAL.qEvents)>
   
        <!--- bounds check after expanding Repeaters --->
        <cfif isdefined("arguments.to")>
           	<cfset LOCAL.lTo = arguments.to>
        <cfelse>
        	<cfif LOCAL.qEventsInfo.getRowCount() eq 1>
	           	<cfset LOCAL.lTo = fix(LOCAL.qEventsInfo.maxStart) + 1> 
			<cfelse>
            	<cfset LOCAL.lTo = fix(from)>
            </cfif>
        </cfif>
	                 
    	<cfset LOCAL.hasRepeater = false>
        <cfset LOCAL.hasSpan = false>
   
 
		<!--- ### Handle Repeaters ### --->
        <!--- Repeaters are VERY costly to expand.  The code below checks that a repeater even exists before performing the expansion of repeaters. Billy Hates Repeaters... and calendars! ---> 
		<cfif arguments.expandRepeaters EQ true AND LOCAL.qEventsInfo.repeater GT 0>
            <cfset LOCAL.hasRepeater = true>
            
            <!--- Get the repeaters expanded using Ben Nadel's calendar code --->
            <cfinvoke component="repeater" method="GetEvents" returnvariable="LOCAL.qEvents">
                <cfinvokeargument name="to" value="#fix(LOCAL.qEventsInfo.maxEnd)#">
                <cfinvokeargument name="from" value="#fix(LOCAL.qEventsInfo.minStart)#">
                <cfinvokeargument name="qEvents" value="#LOCAL.qEvents#">
                <cfinvokeargument name="datasource" value="#variables.datasource#">
            </cfinvoke>

		</cfif>
        
        <!--- ### Handle Spans ### --->
        <!--- Spans are even more costly to expand.  Billy Hates Repeaters, Spans, ... and calendars! ---> 
        <cfif arguments.expandSpans EQ true>
        
        	<!--- query of spans --->
            <cfquery dbtype="query" name="LOCAL.qEventSpans">
                select * from [LOCAL].qEvents
                where (calSpan > 0 AND repeatType = 0) AND (calSpan <> 1 OR allday <> 'true')
            </cfquery> 
        
        	<cfif LOCAL.qEventSpans.getRowCount() gt 0>
            	<cfset LOCAL.hasSpan = true>
                <cfset LOCAL.qColumnlist = LOCAL.qEvents.columnList>
                <cfset LOCAL.qColumnlist = ListSetAt(LOCAL.qColumnlist, ListFindNoCase(LOCAL.qColumnlist, "STARTDATE"), "(CAST(startDate as DATE)) AS startDate")> 
                <cfset LOCAL.qColumnlist = ListSetAt(LOCAL.qColumnlist, ListFindNoCase(LOCAL.qColumnlist, "ENDDATE"), "(CAST(endDate as DATE)) AS endDate")> 
                
                <cfloop query="LOCAL.qEventSpans">
                    <!--- may need change to gt and lt --->
                    <cfset LOCAL.retval = "">
                    <cfif dateCompare(LOCAL.qEventSpans.StartDate, arguments.from) gte 0 AND dateCompare(LOCAL.qEventSpans.StartDate, LOCAL.lTo) lte 0>        
                        <cfset LOCAL.retVal = LOCAL.qEventSpans.StartDate>
				        <cfset queryCopyRow(qDest: LOCAL.qEvents, qSource: LOCAL.qEventSpans, sourceRow: LOCAL.qEventSpans.currentRow)>
                        <cfset LOCAL.qEvents["groupedEndDate"][LOCAL.qEvents.RecordCount] = fix(LOCAL.qEventSpans.StartDate) + 1>
						<cfif dateCompare(LOCAL.qEventSpans.startDate, fix(LOCAL.qEventSpans.startDate)) EQ 0>
							<cfset LOCAL.qEvents["CALSPAN"][LOCAL.qEvents.RecordCount] = 1>
                        	<cfset LOCAL.qEvents["ALLDAY"][LOCAL.qEvents.RecordCount] = true>
                    	<cfelse>
                        	<cfset LOCAL.qEvents["CALSPAN"][LOCAL.qEvents.RecordCount] = 0>
                        	<cfset LOCAL.qEvents["ALLDAY"][LOCAL.qEvents.RecordCount] = false>
                        </cfif>
                    </cfif> 	
                    
                    <!--- take one day off for all day events --->
                    <cfif dateCompare(fix(LOCAL.qEventSpans.EndDate), LOCAL.qEventSpans.EndDate) eq 0>	
                        <cfset LOCAL.spanEnd = fix(LOCAL.qEventSpans.EndDate) - 1>
                    <cfelse>
                        <cfset LOCAL.spanEnd = fix(LOCAL.qEventSpans.EndDate)>
                    </cfif>
                            
                    <cfloop from="#fix(LOCAL.qEventSpans.StartDate) + 1#" to="#LOCAL.spanEnd#" index="LOCAL.dateIndex">
                        <cfif LOCAL.dateIndex GTE fix(arguments.from)>
                            <cfset LOCAL.retVal = LOCAL.dateIndex >
                            <cfset queryCopyRow(qDest: LOCAL.qEvents, qSource: LOCAL.qEventSpans, sourceRow: LOCAL.qEventSpans.currentRow)>
                            <cfset LOCAL.qEvents["groupedStartDate"][LOCAL.qEvents.RecordCount] = LOCAL.retval>
	                        <cfset LOCAL.qEvents["CALSPAN"][LOCAL.qEvents.RecordCount] = 1>
							
							<!--- See if the created span date index != span end date.  for ALLDAY, this should always be the case --->
							<cfif LOCAL.dateIndex neq fix(LOCAL.qEvents["endDate"][LOCAL.qEvents.RecordCount])>
	                        	<cfset LOCAL.qEvents["ALLDAY"][LOCAL.qEvents.RecordCount] = true>
                                <cfset LOCAL.qEvents["groupedEndDate"][LOCAL.qEvents.RecordCount] = LOCAL.dateIndex + 1>
								<cfset LOCAL.qEvents["CALSPAN"][LOCAL.qEvents.RecordCount] = 1>
                            <cfelse>
   	                        	<cfset LOCAL.qEvents["ALLDAY"][LOCAL.qEvents.RecordCount] = false>
								<cfset LOCAL.qEvents["CALSPAN"][LOCAL.qEvents.RecordCount] = 0>
                            </cfif>                                			
                        </cfif>
                    </cfloop>
                </cfloop> <!--- end of qEventSpans loop --->
            </cfif>
        </cfif>
		<!--- END OF SPANNED EVENTS --->
 
        <cfset LOCAL.qColumnlist = LOCAL.qEvents.columnList>
        <cfset LOCAL.qColumnlist = ListSetAt(LOCAL.qColumnlist, ListFindNoCase(LOCAL.qColumnlist, "GROUPEDSTARTDATE"), "(CAST(GROUPEDSTARTDATE as DATE)) AS GROUPEDSTARTDATE")>  
        <cfset LOCAL.qColumnlist = ListSetAt(LOCAL.qColumnlist, ListFindNoCase(LOCAL.qColumnlist, "GROUPEDENDDATE"), "(CAST(groupedendDate as DATE)) AS groupedenddate")>
        <cfset LOCAL.qColumnlist = ListSetAt(LOCAL.qColumnlist, ListFindNoCase(LOCAL.qColumnlist, "STARTDATE"), "(CAST(startDate as DATE)) AS startDate")> 
        <cfset LOCAL.qColumnlist = ListSetAt(LOCAL.qColumnlist, ListFindNoCase(LOCAL.qColumnlist, "ENDDATE"), "(CAST(endDate as DATE)) AS endDate")> 
        
        <cfif (LOCAL.hasSpan neq TRUE AND LOCAL.hasRepeater neq TRUE)>
			<!--- Cast all the dates to javatype for RAW query--->
            <cfquery dbtype="query" name="LOCAL.qEvents">
                select #LOCAL.qColumnlist# from [LOCAL].qEvents
            </cfquery>
		<cfelse>
            <!--- the two cases are identical except for the maxrows needed to limit the query --->
			<cfif isdefined("arguments.limit") and arguments.nearestDay eq false>
            	<!--- hard limit results, Filter/Cleanup extra spans and repeaters --->
                <cfquery dbtype="query" name="LOCAL.qEvents" maxrows="#arguments.limit#">
                    select #LOCAL.qColumnlist# from [LOCAL].qEvents where 0=0
                    <cfif isDefined("arguments.to")>
	                    and groupedStartDate <= <cfqueryparam cfsqltype="cf_sql_timestamp" value="#arguments.to#">
                    </cfif>
					<cfif LOCAL.hasRepeater EQ true>
                    	and (repeatType = 0 OR (endDate > <cfqueryparam cfsqltype="cf_sql_timestamp" value="#arguments.from#">))
                	</cfif>
                    	and ((calSpan <= 0 OR repeatType <> 0) OR (calSpan = 1 AND allday = 'true'))
                    order by groupedStartDate, startDate
                </cfquery>   
 			<cfelse>
            	<!--- nearest day code, Filter/Cleanup extra spans and repeaters --->
                <cfquery dbtype="query" name="LOCAL.qEvents">
                    select #LOCAL.qColumnlist# from [LOCAL].qEvents where 0=0
                    <cfif isDefined("arguments.to")>
                    	and groupedStartDate <= <cfqueryparam cfsqltype="cf_sql_timestamp" value="#arguments.to#">
                 	</cfif>
					<cfif LOCAL.hasRepeater EQ true>
                    	and (repeatType = 0 OR (endDate > <cfqueryparam cfsqltype="cf_sql_timestamp" value="#arguments.from#">))
                	</cfif>
                    	and ((calSpan <= 0 OR repeatType <> 0) OR (calSpan = 1 AND allday = 'true'))
                    order by groupedStartDate, startDate
                </cfquery>

                <!--- WE 11/19/2011 - The following may need a rewrite and be able to be combined with the above query --->
				<!--- handles nearest day after expansion of events has occured --->
                <cfset LOCAL.qEventsInfo = getInfoFromQuery(qEvents: LOCAL.qEvents)>           

                <cfif arguments.nearestDay eq true AND LOCAL.qEvents.getRowCount() gte arguments.limit>	
                    <cfset LOCAL.lMaxStart = fix(LOCAL.qEvents['groupedStartDate'][arguments.limit]) + 1>
                <cfelse>
                    <cfset LOCAL.lMaxStart = fix(LOCAL.qEventsInfo.maxStart) + 1> 	
                </cfif>    
                
                <cfquery dbtype="query" name="LOCAL.qEvents">
                    select * from [LOCAL].qEvents where
                    groupedStartDate < <cfqueryparam cfsqltype="cf_sql_timestamp" value="#LOCAL.lMaxStart#">
                </cfquery>
            </cfif>
        </cfif>
  		
        <!--- crap hack for making sure groupedstartdate are today for spans --->
        <cfif arguments.expandSpans eq FALSE>
            <cfset LOCAL.qColumnlist = LOCAL.qEvents.columnList>
        	<cfset LOCAL.qColumnlist = ListSetAt(LOCAL.qColumnlist, ListFindNoCase(LOCAL.qColumnlist, "GROUPEDSTARTDATE"), "(CAST(#fix(arguments.from)# as DATE)) AS GROUPEDSTARTDATE")>  
                
            <cfquery dbtype="query" name="LOCAL.qEvents">
            	select #LOCAL.qColumnlist# from [LOCAL].qEvents where groupedStartDate < <cfqueryparam cfsqltype="cf_sql_timestamp" value="#arguments.from#">
                UNION
                select * from [LOCAL].qEvents where groupedStartDate >= <cfqueryparam cfsqltype="cf_sql_timestamp" value="#arguments.from#">
                order by groupedstartDate asc
            </cfquery>
    
        </cfif>
        
		<cfreturn LOCAL.qEvents>
   </cffunction>
   
   <!--- Copies a query row to another query
   		 The queries MUST have identical attributes --->
   <cffunction name="queryCopyRow" access="private" output="false" returntype="void">
   		<cfargument name="qDest" type="query">
        <cfargument name="qSource" type="query"> 
        <cfargument name="sourceRow" type="numeric">
        <cfset var i = "">
        <cfset var rowNum = "">
        		
		<cfset rowNum = QueryAddRow(arguments.qDest) />
                    
    	<!--- Set query data in the event query. --->
        <cfloop list="#qSource.columnList#" delimiters="," index="i">
        	<cfswitch expression="#i#">
	            <cfdefaultcase>
					<cfset arguments.qDest[ "#i#" ][rowNum] = arguments.qSource["#i#"]["#arguments.sourceRow#"]>
                </cfdefaultcase>
            </cfswitch>
        </cfloop>
        <cfreturn>
   </cffunction>
   
     <!--- gets useful date info from a calendar query... example date range --->
   <cffunction name="getInfoFromQuery" returntype="query" access="private" output="false"> 
   		<cfargument name="qEvents" type="query" required="true">
        <cfset var LOCAL = structNew()>
        
        <cfquery dbtype="query" name="LOCAL.qEventsInfo">
        	select max(startDate) as maxStart, max(enddate) as maxEnd, min(startdate) as minStart, min(enddate) as minEnd , max(repeatType) as repeater, count(*) as eventCount 
            from arguments.qEvents
        </cfquery>        
        
        <cfreturn LOCAL.qEventsInfo>
   </cffunction>
   
   <cffunction name="createAttributeList" returntype="string" access="private" output="false" hint="creates a trusted or secure list of attributes">
   		<cfargument name="attributes" type="string" required="false" default="">
        <cfset var LOCAL = structNew()>
        <cfset LOCAL.retAttributes = replaceNoCase("CalID, startDate, endDate, CalEvent, CalCategory, CalShow, allDay, calPlace, repeatType", " ", "", "all")>
        <cfloop list="#arguments.attributes#" index="LOCAL.listIndex">
        	<cfswitch expression="#lcase(trim(LOCAL.listIndex))#">
            	<cfcase value="caldesc">
                	<cfset LOCAL.retAttributes = listAppend(LOCAL.retAttributes, "calDesc")>
                </cfcase>
                <cfcase value="calcontact">
                	<cfset LOCAL.retAttributes = listAppend(LOCAL.retAttributes, "calContact")>
                </cfcase>
                <cfcase value="calphone">
                	<cfset LOCAL.retAttributes = listAppend(LOCAL.retAttributes, "calPhone")>
                </cfcase>
                <cfcase value="calemail">
                	<cfset LOCAL.retAttributes = listAppend(LOCAL.retAttributes, "calEMail")>
                </cfcase>
            </cfswitch>
        </cfloop>

		<!--- admin attributes --->
        <cfif variables.admin EQ true>
            <cfloop list="#arguments.attributes#" index="LOCAL.listIndex">
                <cfswitch expression="#lcase(trim(LOCAL.listIndex))#">
                    <cfcase value="color">
                        <cfset LOCAL.retAttributes = listAppend(LOCAL.retAttributes, "color")>
                    </cfcase>
                    <cfcase value="approved">
                        <cfset LOCAL.retAttributes = listAppend(LOCAL.retAttributes, "approved")>
                    </cfcase>
                </cfswitch>
            </cfloop>
		</cfif>
        
        <cfreturn LOCAL.retAttributes>
   </cffunction>

   <!--- get the RAW SQL calendar query.  This query does not include expanded spans or repeaters --->
   <cffunction name="getRawData" returntype="query" access="public" output="false" hint="get the raw calendar query from SQL">
		<cfargument name="CalID" type="numeric" required="false" default="-1">
		<cfargument name="category" type="string" required="false" default="" hint="Can be a single string category name">
        <cfargument name="catID" type="string" required="false" default="" hint="Can be a single category ID or a list of category IDs">
        <cfargument name="featured" type="boolean" required="false" default="true" hint="true for featured / homepage events">
		<cfargument name="from" type="date" required="false" default="#now()#" hint="starting date for event listing">
        <cfargument name="to" type="date" required="false" hint="ending date for event listing, overrides limit">
        <cfargument name="nearestDay" type="boolean" required="false" default="false" hint="pulls in number of results to the nearest day.  Only applies when using limit.">
        <cfargument name="queryType" type="string" required="false" default="" hint="type are 'events, info'">
        <cfargument name="attributes" type="string" required="false">
        <cfargument name="keywords" type="string" required="false">

		<cfset var LOCAL = structNew()>

        <cfif isDefined("arguments.keywords") and listLen(arguments.keywords) GT 5>
            <cfthrow type="error" message="keywords list greater than 5">
        </cfif>

        <!--- set the list of attributes to get --->
        <cfif isDefined("arguments.attributes")>
        	<cfinvoke method="createAttributeList" returnvariable="LOCAL.attributes">
            	<cfinvokeargument name="attributes" value="#arguments.attributes#">
            </cfinvoke>
		<cfelse>
        	<cfinvoke method="createAttributeList" returnvariable="LOCAL.attributes" />
		</cfif>	        	
        
        <!--- ID query? --->
        <cfif arguments.calID NEQ -1>
			<cfset LOCAL.isID = true>
        <cfelse>
            <cfset LOCAL.isID = false>
        </cfif>
        
        <cfif variables.admin EQ true>
        	<cfset LOCAL.calTable = "calendarADMIN">
        <cfelse>
        	<cfset LOCAL.calTable = "calendar">
		</cfif>
        
 		<!--- the attempt here is to package as much in one query as possible so MS SQL will optimize --->               
        <cfquery datasource="#variables.datasource#" name="LOCAL.qEvents">                    
	        with eventsCore(#LOCAL.attributes#)
			AS
			(
            	select #LOCAL.attributes#
                From #LOCAL.calTable#
                join areaCategories on (areaCategories.areaCat = #LOCAL.calTable#.calCategory) 
                where '0'='0'
                <cfif LOCAL.isID EQ TRUE>
               		and calId = <cfqueryparam cfsqltype="cf_sql_integer" value="#arguments.calId#"> 	
                <cfelse>
                    <cfif isDefined("arguments.keywords")>
                        <cfloop list="#arguments.keywords#" delimiters="," index="LOCAL.keywordIndex">
                            and (calEvent like <cfqueryparam cfsqltype="cf_sql_varchar" value="%#LOCAL.keywordIndex#%">
                                or calDesc like <cfqueryparam cfsqltype="cf_sql_varchar" value="%#LOCAL.keywordIndex#%">
                                or calPlace like <cfqueryparam cfsqltype="cf_sql_varchar" value="%#LOCAL.keywordIndex#%">                  
                            )
                        </cfloop>
                    </cfif>
					<cfif arguments.featured eq true>
                        and calShow = <cfqueryparam cfsqltype="cf_sql_varchar" value="true"> 
                    </cfif> 
                    <cfif arguments.catID neq "">
                        <cfif arguments.featured eq true>or<cfelse>and</cfif> areaCategories.areaCatID in (<cfqueryparam list="true" cfsqltype="cf_sql_integer" value="#arguments.catID#">)
                    </cfif>
                    <cfif arguments.category neq "">
                        <cfif arguments.featured eq true>or<cfelse>and</cfif> calCategory = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.category#">
                    </cfif>                   
                </cfif>
            ),
            eventsFixAllDay(#LOCAL.attributes#)
            AS
            (
            	SELECT #LOCAL.attributes#
                FROM eventsCore
                WHERE '0'='0' 
                <cfif LOCAL.isID NEQ TRUE>
                	and <cfqueryparam cfsqltype="cf_sql_timestamp" value="#arguments.from#"> <= endDate 
				</cfif>
                and allDay = 'false'
                        
                UNION 
                        
                SELECT #ListSetAt(LOCAL.attributes, ListFindNoCase(LOCAL.attributes, "endDate"), "DateAdd(day, datediff(day, 0, (endDate)),1) as endDate")# 
                FROM eventsCore
                WHERE '0'='0'
	            <cfif LOCAL.isID NEQ TRUE>
					and <cfqueryparam cfsqltype="cf_sql_timestamp" value="#arguments.from#"> < DateAdd(day, datediff(day, 0, (endDate)),1) 	</cfif>
                and allDay = 'true'                                        
            ),
            eventsLimit(#LOCAL.attributes#)
            AS
            (
                <cfif LOCAL.isID EQ TRUE OR isDefined("arguments.to")>
                	select * from eventsFixAllDay
                    <cfif LOCAL.isID NEQ TRUE>
                    	where startDate <= <cfqueryparam cfsqltype="cf_sql_timestamp" value="#arguments.to#">
                	</cfif>
                <cfelse>
                	select * from (
                        select <cfif arguments.nearestDay neq true>
                        TOP 10
                        </cfif> 
                        * from eventsFixAllDay 
                        where
                        startDate < DateAdd(day, datediff(day, 0, (
                            select max(startDate) from (
                                select top 10 startDate 
                                from eventsFixAllDay
                                order by startDate asc
                            ) as ev
                        )), 1)
                        <cfif arguments.nearestDay neq true>
	                    order by startDate ASC
                        </cfif>                    
                    ) as ev2
                 </cfif>
            )
            <!--- add the actual main query --->
           <cfswitch expression="#arguments.queryType#">
                <cfcase value="info">
                    select max(startDate) as maxStart, max(enddate) as maxEnd, min(startdate) as minStart, min(enddate) as minEnd, max(repeatType) as repeater, count(*) as eventCount from eventsLimit
                </cfcase>
                <cfdefaultcase>
                    select *, startdate as groupedstartdate, enddate as groupedenddate, ((CAST (datediff(day, 0, (endDate)) as INT) - CAST (datediff(day, 0, (startDate)) as INT)) ^ repeatType) as calSpan from eventsLimit order by startDate ASC, endDate DESC
                </cfdefaultcase>            
            </cfswitch>
            </cfquery>
               
		<cfreturn LOCAL.qEvents>            		
   </cffunction>
   
   <!--- enforce bounds on a number --->
   <cffunction name="numericBoundsCheck" returntype="numeric" access="public" hint="enforces bounds">
   		<cfargument name="num" type="numeric" required="true">
        <cfargument name="min" type="numeric" required="true">
        <cfargument name="max" type="numeric" required="true">
        <cfargument name="forceInt" type="boolean" default="false">
        
        <cfif arguments.forceInt eq true>
        	<cfset arguments.num = int(arguments.num)>
		</cfif>
        
        <cfif arguments.num gt arguments.max>
        	<cfset arguments.num = arguments.max>
        <cfelseif arguments.num lt arguments.min>
        	<cfset arguments.num = arguments.min>
        </cfif>
        
        <cfreturn arguments.num>
   </cffunction>
  
  	<!--- true if the event is a span --->
	<cffunction name="isSpanEvent" returntype="boolean" output="false" access="private" hint="returns true if the event is a true span">
    	<cfargument name="calSpan" type="numeric" required="true">
        <cfargument name="repeatType" type="numeric" required="true">
        <cfargument name="allday" type="boolean" required="true">
        <cfreturn (arguments.calSpan gt 0 and arguments.repeatType eq 0) and (arguments.calSpan neq 1 or arguments.allday neq true)>
    </cffunction> 

	<cffunction name="formatDateTime" returntype="string" output="false" access="public">
    	<cfargument name="startDate" type="date" required="true">
    	<cfargument name="endDate" type="date" required="true">
        <cfargument name="allDay" type="boolean" required="true">
    	<cfargument name="groupDays" type="boolean" required="false" default="false">
        <cfargument name="dateMask" type="string" required="false" default="mmm d" hint="TimeFormat Mask.">
        <cfargument name="timeMask" type="string" required="false" default="h:mm tt" hint="DateFormat Mask.">
        
        <cfset var rDateTime = "">
        
        <cfif arguments.allDay eq true>
        	<cfif fix(arguments.endDate) - fix(arguments.startDate) lt 2>
				<cfset rDateTime = "All Day">
            <cfelse>
 				<cfset rDateTime = rDateTime & dateformat(arguments.startDate, arguments.dateMask)>
				<cfset rDateTime = rDateTime & " - ">
				<cfset rDateTime = rDateTime & dateformat(fix(arguments.endDate) - 1, arguments.dateMask)>
            </cfif>        
        <cfelse>     
        	<cfif datepart('d', arguments.startDate) eq datepart('d', arguments.endDate)>
            	<cfset rDateTime = "#timeformat(arguments.startDate, arguments.timeMask)# - #timeformat(arguments.endDate, arguments.timeMask)#"> 
            <cfelse>
                <cfset rDateTime = "">
               	<cfset rDateTime = rDateTime & "#timeformat(arguments.startDate, arguments.timeMask)#">
                <cfif arguments.groupDays eq false and datepart('d', arguments.startdate) neq datepart('d', now())>
                	<cfset rDateTime = rDateTime & " | #dateformat(arguments.startDate, arguments.dateMask)#"> 
                </cfif>
                
				<cfset rDateTime = rDateTime & " - ">
                <cfset rDateTime = rDateTime & "#timeformat(arguments.enddate, arguments.timeMask)#">
                
				<cfif datepart('d', arguments.endDate) neq datepart('d', now())>
                	<cfset rDateTime = rDateTime & " | #dateformat(arguments.endDate, arguments.dateMask)#"> 
                </cfif>
             </cfif>
         </cfif>
         <cfreturn rDateTime>
    </cffunction>
    
   	<cffunction name="getCategories" returntype="query" access="public" output="false" hint="get calendar categories">
    	<cfquery datasource="#variables.datasource#" name="qCategories">
        	select areaCatID as ID, areaCat as Category, color
            from areacategories where CalApp = '1'
            order by areaCat asc
        </cfquery>
        
        <cfreturn qCategories>
    </cffunction> 
   
    <cffunction name="getEvent" returntype="query" access="public" output="false" hint="get event details">
    	  <cfargument name="calId" required="true" type="numeric">
          <cfstoredproc datasource="#variables.datasource#" procedure="calendarGETevent">
            <cfprocparam cfsqltype="cf_sql_integer" value="#calID#">
            <cfprocresult name="qEvent">
          </cfstoredproc>
          <cfreturn qEvent>
    </cffunction>
    
</cfcomponent>
	