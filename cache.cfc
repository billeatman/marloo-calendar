<cfcomponent displayname="calcache">
	<cfset variables.maxItems = 50>
    <cfset variables.timeSpan = createTimeSpan(0,0,1,0)>
   
   <cffunction name="init" returntype="calcache">
   		<cfargument name="maxItems" type="numeric" required="false" hint="Number of distinct requests to cache." default="#variables.maxItems#">
        <cfargument name="timeSpan" type="date" required="false" hint="Use CreateTimeSpan to generate this parameter." default="#variables.timeSpan#">
        <cfset variables.maxItems = arguments.maxItems> 
        <cfset variables.timeSpan = arguments.timeSpan> 
		<cfscript>
        variables.cache = structNew();
		variables.qCache = queryNew("requeststr, hits, data, hash, dayindex, from, nextEventDate, validUntilDate", "CF_SQL_VARCHAR, CF_SQL_INTEGER, CF_SQL_VARCHAR, CF_SQL_VARCHAR, CF_SQL_INTEGER, CF_SQL_TIMESTAMP, CF_SQL_TIMESTAMP, CF_SQL_TIMESTAMP");
   		</cfscript>
		<cfreturn this>
   </cffunction>
   
   <cffunction name="generateHash" returntype="string" access="public" hint="creates a hash based on passed arguments">
   		<cfargument name="from" type="date" required="true">
		<cfset var LOCAL = structNew()>   		

		<cfset LOCAL.argList = StructKeyList(arguments)>
        <cfset LOCAL.argList = listSort(LOCAL.argList, "text", "asc", ",")>

        <cfset LOCAL.args = "">
        <cfloop list="#LOCAL.argList#" index="LOCAL.argKey">
        	<cfif LOCAL.argKey NEQ 'from' OR datecompare(fix(arguments.from), arguments.from) EQ 0>
				<cfset LOCAL.args = LOCAL.args & LOCAL.argKey & tostring(arguments["#LOCAL.argKey#"])>
        	</cfif>
        </cfloop>

		<cfset LOCAL.myhash = hash(LOCAL.args, 'md5')> 
        
        <cfreturn LOCAL.myhash>    
   </cffunction>

   <cffunction name="checkCache" returntype="string" access="public" hint="checks the cache based on the passed hash">
		<cfargument name="hash" required="true" type="string">
		<cfargument name="from" required="true" type="date">
        <cfset var LOCAL = structNew()>
           
        <cfquery dbtype="query" name="LOCAL.qCache">
        	select data,[from], nexteventDate, validUntilDate from variables.qCache
       		where hash = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.hash#">     
        </cfquery>
  
		<!--- does the record exist --->
		<cfif LOCAL.qCache.recordCount EQ 1>
        	<!--- Check that the cache hit is still fresh :-) --->
            <cfif dateCompare(now(),LOCAL.qCache.validUntilDate) LTE 0>
				<!--- if the date From is shifting, make sure we are not at the next event --->  
                <cfif isDefined("arguments.from") AND (dateCompare(arguments.from, parseDateTime(LOCAL.qCache.from[1])) GTE 0 AND dateCompare(arguments.from, parseDateTime(LOCAL.qCache.nextEventDate[1])) LTE 0)>
                    <cfset variables.cache["#arguments.hash#"] = variables.cache["#arguments.hash#"] + 1>
                    <cfreturn LOCAL.qCache.data[1]>
                </cfif>
        	</cfif>
        </cfif>
        <cfreturn false>
   </cffunction>

   <cffunction name="cacheAdd" returntype="void" access="public" hint="adds to the cache">
   		<cfargument name="from" required="false" type="date" default="#now()#">
        <cfargument name="nextEventDate" required="true" type="date">
        <cfargument name="hash" required="true" type="string">
        <cfargument name="cacheData" required="true" type="string">
        
		<cfset var LOCAL = structNew()>
        
        <!--- merge the data from the hit count structure with the cache query --->
        <!--- Note:  We do this only on cacheAdd because it is time expensive to do --->
        <cftry>
		<!--- set the hits from the cache struct --->
        	<cfset LOCAL.newcache = structnew()>
            <cfloop query="variables.qCache" >
            	<cfset variables.qCache.hits[currentRow] = variables.cache["#variables.qCache.hash[currentRow]#"]>
                <cfset LOCAL.newcache["#variables.qCache.hash[currentRow]#"] = 0>
            </cfloop>
            <cfcatch>
            	<!--- reset the cache vars --->
				<cfinvoke method="init" />
            </cfcatch>
        </cftry>
	            
		<cfset variables.cache = LOCAL.newcache>
		<!--- attributes: hits, dayindex, data, hash, from, eventDate --->
        <cfquery dbtype="query" name="variables.qCache" maxrows="#variables.maxItems#">
           	select CAST(hits as INTEGER) as hits, CAST(dayindex as INTEGER) as dayindex, data, hash, [from], nextEventDate, validUntilDate from variables.qCache
            where hash <> <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.hash#">
            order by dayindex, hits desc
        </cfquery>
		
        <!--- add row to cache query object --->	
		<cfset LOCAL.rowNum = QueryAddRow(variables.qCache) />
		<cfset variables.cache["#arguments.hash#"] = 0>
        <cfset variables.qCache.from[LOCAL.rowNum] = parseDateTime(arguments.from)>
        <cfset variables.qCache.nextEventDate[LOCAL.rowNum] = arguments.nextEventDate>
        <cfset variables.qCache.validUntilDate[LOCAL.rowNum] = now() + variables.timeSpan>
        <cfset variables.qCache.hits[LOCAL.rowNum] = 0>
        <cfset variables.qCache.data[LOCAL.rowNum] = arguments.cacheData>
        <cfset variables.qCache.hash[LOCAL.rowNum] = arguments.hash>
        <cfset variables.qCache.dayindex[LOCAL.rowNum] = fix(now())>
   </cffunction>

</cfcomponent>