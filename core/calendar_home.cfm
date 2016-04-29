<!--- Get Events from calcore --->
<cfinvoke component="#application.util.calcore#" method="getEvents" returnvariable="calendar">
	<cfinvokeargument name="from" value="#thisCalMonth#">
	<cfinvokeargument name="to" value="#DateAdd('n', -1, fix(thisCalMonth) + DaysInMonth(thisCalMonth))#"> 
	<cfinvokeargument name="featured" value="false"> 
	<cfinvokeargument name="attributes" value="color, approved"> 
</cfinvoke>

<!--- reformat events for calendar display --->

<!--- reorder to put spans before "all day" events ---> 
<cfquery dbtype="query" name="calendar">
	select * from calendar
    order by startDate ASC, endDate DESC
</cfquery>

<cfset calSquare = arrayNew(2)>
<cfset ArrayResize(calSquare, totalDays)> 

<cffunction name="insertIntoArray" access="private" returntype="array" hint="Inserts struct in the first open position in array, or appends.">
	<cfargument name="array" type="array" required="true" hint="Calendar array">
    <cfargument name="value" type="struct" required="true" hint="Struct for day">
    <cfargument name="position" type="numeric" required="false" hint="Force a position in the array">
    
	<cfset LOCAL = structNew()>

	<cfif isDefined("arguments.position")>
        <cfif arguments.position GT arrayLen(arguments.array)>
        	<cfset arrayResize(arguments.array, position - 1)>
            <cfset arrayAppend(arguments.array, arguments.value)>
		<cfelse>
			<cfset arrayInsertAt(arguments.array, arguments.position, arguments.value)>		
    	</cfif>
    <cfelse>
    	<cfset LOCAL.found = false>
    	<!--- find first free array square --->
        <cfif arrayLen(arguments.array) GT 1>
            <cfloop from="1" to="#arrayLen(arguments.array)#" index="LOCAL.i">
                <cfif NOT ArrayIsDefined(arguments.array, LOCAL.i)>
                    <cfset LOCAL.found = true>
                    <cfset arguments.array[LOCAL.i] = arguments.value>
                    <cfbreak>        	
                </cfif>
            </cfloop>
        </cfif> 
    	<cfif LOCAL.found EQ false>
        	<cfset arrayAppend(arguments.array, arguments.value)>
        </cfif>
    </cfif>
    
    <cfreturn arguments.array>
</cffunction> 

<!--- build the calendar day square array --->
<cfloop query="calendar">
	<cfset myEvent = structnew()>

	<!--- is span --->
	<cfif dateCompare(startDate, groupedstartDate) NEQ 0 OR dateCompare(endDate, groupedendDate) NEQ 0>
        <cfset myEvent.span = true>
		<cfset myEvent.spanfirst = false>
        <cfset myEvent.spanlast = false>    
        <!--- is span first --->
		<cfif dateCompare(startDate, groupedstartDate) EQ 0 AND dateCompare(endDate, groupedendDate) NEQ 0>
            <cfset myEvent.spanfirst = true>
        </cfif>
        <!--- is span last --->
        <cfif dateCompare(startDate, groupedstartDate) NEQ 0 AND dateCompare(endDate, groupedendDate) EQ 0>
            <cfset myEvent.spanlast = true>
        </cfif>
    <cfelse>
	    <cfset myEvent.span = false>
    </cfif>

    <cfset myEvent.event = calendar.CalEvent>
    <cfset myEvent.calid = calendar.calid>
    <cfset myEvent.color = calendar.color>
    <cfset myEvent.approved = calendar.approved>
    <cfset myEvent.day_index = fix(calendar.GroupedStartDate)>
	<cfset myEvent.allDay = calendar.allDay>
	<cfset myEvent.startTime = ReplaceNoCase(ReplaceNoCase(lcase(timeFormat(calendar.startDate, 'h:mmt')), ':00', ''), 'a', '')>
	<cfset myEvent.endTime = ReplaceNoCase(ReplaceNoCase(lcase(timeFormat(calendar.endDate, 'h:mmt')), ':00', ''), 'a', '')>
	<cfset dayIndex = val(DateFormat(calendar.GroupedStartDate, 'd'))>
	
    <!--- tricky part where we decide where in the array to put stuff --->
    <cfset position = -1>
	<cfif myEvent.span EQ true AND myEvent.spanfirst EQ false AND (dayIndex - 1) GTE 1>
    	<cfloop from="1" to="#arrayLen(calSquare[dayIndex - 1])#" index="rowIndex">
			<cfif ArrayIsDefined(calSquare[dayIndex - 1], rowIndex) AND myEvent.calid EQ calSquare[dayIndex - 1][rowIndex].calid>
           		<cfset position = rowIndex>
                <cfbreak>
            </cfif>
        </cfloop>
	</cfif>
    
    <!--- insert event into calendar array --->       
    <cfif position gt 1>
		<cfset calSquare[dayIndex] = insertIntoArray(array: calSquare[dayIndex], value: myEvent, position: position)>
    <cfelse>
		<cfset calSquare[dayIndex] = insertIntoArray(array: calSquare[dayIndex], value: myEvent)>
	</cfif>
</cfloop> 

