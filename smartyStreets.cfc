<cfcomponent output="false">

<cffunction name="init" output="false">
	<cfargument name="htmlAuth" type="string" required="true">
	<cfargument name="authID" type="string" required="true">
	<cfargument name="authToken" type="string" required="true">
	<cfargument name="serviceTimeout" type="numeric" default="5">
	<cfargument name="debug" type="boolean" default="false">
	
	<cfset structAppend( this, arguments, true )>
	
	<cfreturn this>
</cffunction>


<cffunction name="zipLookup" output="false" access="public" returnType="struct">
	<cfargument name="zip" type="string" required="true">
	
	<cfset var address = 0>
	<cfset var a = 0>
	<cfset var response = 0>
	<cfset var field = "">
	<cfset var params = 0>
	<cfset var out = {
		success = true
	,	matched = false
	,	suggestions = []
	,	errorMsg = ""
	}>
	
	<cftry>
		<cfset response= httpClientGet(
			url= "https://api.smartystreets.com/zipcode"
		,	params= {
				"auth-id" = this.authID
			,	"auth-token" = this.authToken
			,	"zipcode" = arguments.zip
			}
		,	requestTimeOut= this.serviceTimeout
		)>
		
		<cfset out.response = response.fileContent>
		<cfif len( response.errorDetail )>
			<cfset out.success = false>
			<cfset out.errorMsg = "Error: " & response.errorDetail>
		</cfif>
		
		<cfif out.success>
			<cfset out.json = deserializeJson( out.response )>
		</cfif>
		
		<cfcatch>
			<cfset out.success = false>
			<cfset out.errorMsg = "Cfcatch: " & cfcatch.message>
		</cfcatch>
	</cftry>
	
	<cfreturn out>
</cffunction>


<cffunction name="addressValidate" output="false" access="public" returnType="struct">
	<cfargument name="fullname" type="string" default="">
	<cfargument name="address1" type="string" required="true">
	<cfargument name="address2" type="string" default="">
	<cfargument name="city" type="string" required="true">
	<cfargument name="state" type="string" required="true">
	<cfargument name="zip" type="string" required="true">
	<cfargument name="maxSuggestions" type="numeric" default="3">
	
	<cfset var address = 0>
	<cfset var a = 0>
	<cfset var response = 0>
	<cfset var field = "">
	<cfset var params = 0>
	<cfset var out = {
		success = true
	,	matched = false
	,	suggestions = []
	,	errorMsg = ""
	}>
	
	<cftry>
		<cfset response= httpClientGet(
			url= "https://api.smartystreets.com/street-address"
		,	params= {
				"auth-id" = this.authID
			,	"auth-token" = this.authToken
			,	"addressee" = arguments.fullname
			,	"street" = arguments.address1
			,	"street2" = arguments.address2
			,	"city" = arguments.city
			,	"state" = arguments.state
			,	"zipcode" = arguments.zip
			,	"candidates" = arguments.maxSuggestions
			}
		,	requestTimeOut= this.serviceTimeout
		)>
		
		<cfset out.response = response.fileContent>
		<cfif len( response.errorDetail )>
			<cfset out.success = false>
			<cfset out.errorMsg = "Error: " & response.errorDetail>
		</cfif>

		<cfif out.success>
			<cfset out.json = deserializeJson( out.response )>
			<cfloop array="#out.json#" index="a">
				<cfset address = {
					fullname = uCase( structKeyExists( a, "addressee" ) AND len( a.addressee ) ? a.addressee : arguments.fullname )
				,	address1 = uCase( structKeyExists( a, "delivery_line_1" ) ? a.delivery_line_1 : "" )
				,	address2 = uCase( structKeyExists( a, "delivery_line_2" ) ? a.delivery_line_2 : "" )
				,	city = uCase( structKeyExists( a.components, "city_name" ) ? a.components.city_name : "" )
				,	state = ( structKeyExists( a.components, "state_abbreviation" ) ? a.components.state_abbreviation : "" )
				,	zip = a.components.zipcode & ( structKeyExists( a.components, "plus4_code" ) ? "-" & a.components.plus4_code : "" )
				}>
				<!--- check for address differences --->
				<cfif listFind( "Y,S,D", a.analysis.dpv_match_code ) AND arrayLen( out.json ) IS 1>
					<cfset out.matched = true>
					<cfset out.address = address>
				<cfelse>
					<cfset arrayAppend( out.suggestions, address )>
				</cfif>
			</cfloop>
		</cfif>
		
		<cfcatch>
			<cfset out.success = false>
			<cfset out.errorMsg = "Cfcatch: " & cfcatch.message>
		</cfcatch>
	</cftry>
	
	<cfreturn out>
</cffunction>


<cffunction name="httpClientGet" output="false" returnType="struct">
	<cfargument name="url" type="string" required="true">
	<cfargument name="params" type="struct" required="false">
	<cfargument name="requestTimeout" type="numeric" default="-1">
	
	<cfset var httpClient = 0>
	<cfset var httpGet = 0>
	<cfset var stResult = {}>
	
	<cfif structKeyExists( arguments, "params" )>
		<cfset arguments.paramsUrl = this.structToQueryString( arguments.params )>
		<cfif find( "?", arguments.url )>
			<cfset arguments.paramsUrl = replace( arguments.paramsUrl, "?", "&" )>
		</cfif>
		<cfset arguments.url &= arguments.paramsUrl>
	</cfif>
	
	<cfset stResult = arguments>
	<cfset stResult.error = false>
	<cfset stResult.errorDetail = "">
	<cfset stResult.statusCode = 0>
	<cfset stResult.status = "">
	<cfset stResult.fileContent = "">
	
	<cftry>
		<cfset httpClient = createObject( "java", "org.apache.commons.httpclient.HttpClient" ).init()>
		<cfset httpClient.getParams().setParameter( "http.protocol.allow-circular-redirects", javaCast( "boolean", false ) )>
		<cfset httpClient.getParams().setParameter( "http.protocol.content-charset", "utf-8" )>
		
		<cfif arguments.requestTimeout IS NOT -1>
			<cfset httpClient.setTimeout( arguments.requestTimeout * 1000 )>
			<!---<cfset httpClient.getParams().setParameter( "http.socket.timeout", javaCast( "int", arguments.requestTimeout * 1000 ) )>--->
			<!--- <cfset httpClient.setConnectionTimeout( arguments.requestTimeout )> --->
			<!--- <cfset httpParams = httpClient.getParams().setConnectionManagerTimeout( arguments.requestTimeout )> --->
		</cfif>
		
		<cfset httpGet = createObject( "java", "org.apache.commons.httpclient.methods.GetMethod" ).init( stResult.url )>
		<!---<cfset httpGet.getParams().setParameter( "http.method.retry-handler", retryHandler.init( arguments.attempts, false ) )>--->
	
		<cfset httpClient.executeMethod( httpGet )>
		<cfset stResult.fileContent = httpGet.getResponseBodyAsString()>
		<cfset stResult.statusCode = httpGet.getStatusCode()>
		<cfset stResult.status = httpGet.getStatusText()>
		<cfset stResult.charSet = httpGet.getResponseCharSet()>
		<cfset httpGet.releaseConnection()>
		
		<cfif stResult.statusCode IS NOT 200>
			<cfset stResult.error = true>
			<cfset stResult.errorDetail = "StatusCode[#stResult.statusCode#] is not 200">
		</cfif>
		
		<cfcatch>
			<cfset stResult.error = true>
			<cfset stResult.errorDetail = "#cfcatch.type#: #cfcatch.message#">
		</cfcatch>
	</cftry>
	
	<cftry>
		<cfset httpGet.releaseConnection()>
		<cfcatch></cfcatch>
	</cftry>

	<cfreturn stResult>
</cffunction>


<cffunction name="structToQueryString" output="false" returnType="string">
	<cfargument name="stInput" type="struct" required="true">
	<cfargument name="bEncode" type="boolean" default="true">
	<cfargument name="lExclude" type="string" default="">
	<cfargument name="sDelims" type="string" default=",">
	
	<cfset var sOutput = "">
	<cfset var sItem = "">
	<cfset var sValue = "">
	<cfset var amp = "?">
	
	<cfloop item="sItem" collection="#stInput#">
		<cfif NOT len( lExclude ) OR NOT listFindNoCase( lExclude, sItem, sDelims )>
			<cftry>
				<cfset sValue = stInput[ sItem ]>
				<cfif bEncode>
					<cfset sOutput &= amp & lCase( sItem ) & "=" & urlEncodedFormat( sValue )>
				<cfelse>
					<cfset sOutput &= amp & lCase( sItem ) & "=" & sValue>
				</cfif>
				<cfset amp = "&">
				<cfcatch></cfcatch>
			</cftry>
		</cfif>
	</cfloop>
	
	<cfreturn sOutput>
</cffunction>


</cfcomponent>