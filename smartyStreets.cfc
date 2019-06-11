component {
	cfprocessingdirective( preserveCase=true );

	function init(
		required string authID
	,	required string authToken
	,	string htmlAuth= ""
	,	string apiUrl= "https://api.smartystreets.com"
	,	string userAgent= "CFML API Agent 0.1"
	,	numeric httpTimeOut= 60
	,	boolean debug= ( request.debug ?: false )
	) {
		this.authID= arguments.authID;
		this.authToken= arguments.authToken;
		this.htmlAuth= arguments.htmlAuth;
		this.apiUrl= arguments.apiUrl;
		this.userAgent= arguments.userAgent;
		this.httpTimeOut= arguments.httpTimeOut;
		return this;
	}

	function debugLog(required input) {
		if ( structKeyExists( request, "log" ) && isCustomFunction( request.log ) ) {
			if ( isSimpleValue( arguments.input ) ) {
				request.log( "SmartyStreets: " & arguments.input );
			} else {
				request.log( "SmartyStreets: (complex type)" );
				request.log( arguments.input );
			}
		} else if( this.debug ) {
			cftrace( text=( isSimpleValue( arguments.input ) ? arguments.input : "" ), var=arguments.input, category="SmartyStreets", type="information" );
		}
		return;
	}

	struct function zipLookup( required string zipcode ) {
		return this.apiRequest( api= "GET /zipcode", argumentCollection= arguments );
	}

	struct function addressValidate(
		required string addressee
	,	required string street
	,	required string street2
	,	required string city
	,	required string state
	,	required string zipcode
	,	numeric candidates= 3
	) {
		var out= this.apiRequest( api= "GET /street-address", argumentCollection= arguments );
		out.suggestions= [];
		out.matched= false;

		var a= 0;
		var address= 0;
		if ( out.success ) {
			for ( a in out.data ) {
				address= {
					fullname= uCase( structKeyExists( a, "addressee" ) && len( a.addressee ) ? a.addressee : arguments.addressee )
				,	address1= uCase( structKeyExists( a, "delivery_line_1" ) ? a.delivery_line_1 : "" )
				,	address2= uCase( structKeyExists( a, "delivery_line_2" ) ? a.delivery_line_2 : "" )
				,	city= uCase( structKeyExists( a.components, "city_name" ) ? a.components.city_name : "" )
				,	state= ( structKeyExists( a.components, "state_abbreviation" ) ? a.components.state_abbreviation : "" )
				,	zip= a.components.zipcode & ( structKeyExists( a.components, "plus4_code" ) ? "-" & a.components.plus4_code : "" )
				};
				//  check for address differences 
				if ( listFind( "Y,S,D", a.analysis.dpv_match_code ) && arrayLen( out.data ) == 1 ) {
					out.matched= true;
					out.address= address;
				} else {
					arrayAppend( out.suggestions, address );
				}
			}
		}
		return out;
	}

	struct function apiRequest( required string api)  {
		arguments[ "auth-id" ]= this.authID;
		arguments[ "auth-token" ]= this.authToken;
		var http= {};
		var item= "";
		var out= {
			args= arguments
		,	success= false
		,	error= ""
		,	status= ""
		,	statusCode= 0
		,	response= ""
		,	verb= listFirst( arguments.api, " " )
		,	requestUrl= this.apiUrl
		,	data= {}
		};
		out.requestUrl &= listRest( out.args.api, " " );
		structDelete( out.args, "api" );
		// replace {var} in url 
		for ( item in out.args ) {
			// strip NULL values 
			if ( isNull( out.args[ item ] ) ) {
				structDelete( out.args, item );
			} else if ( isSimpleValue( arguments[ item ] ) && arguments[ item ] == "null" ) {
				arguments[ item ]= javaCast( "null", 0 );
			} else if ( findNoCase( "{#item#}", out.requestUrl ) ) {
				out.requestUrl= replaceNoCase( out.requestUrl, "{#item#}", out.args[ item ], "all" );
				structDelete( out.args, item );
			}
		}
		if ( out.verb == "GET" ) {
			out.requestUrl &= this.structToQueryString( out.args, out.requestUrl, true );
		}
		this.debugLog( "API: #uCase( out.verb )#: #out.requestUrl#" );
		this.debugLog( out );
		cftimer( type="debug", label="SmartyStreets request" ) {
			cfhttp( result="http", method=out.verb, url=out.requestUrl, charset="UTF-8", throwOnError=false, userAgent=this.userAgent, timeOut=this.httpTimeOut ) {
				if ( out.verb == "POST" || out.verb == "PUT" || out.verb == "PATCH" ) {
					cfhttpparam( name="content-type", type="header", value="application/json" );
				}
			}
		}
		out.response= toString( http.fileContent );
		out.statusCode= http.responseHeader.Status_Code ?: 500;
		this.debugLog( out.statusCode );
		if ( left( out.statusCode, 1 ) == 4 || left( out.statusCode, 1 ) == 5 ) {
			out.success= false;
			out.error= "status code error: #out.statusCode#";
		} else if ( out.response == "Connection Timeout" || out.response == "Connection Failure" ) {
			out.error= out.response;
		} else if ( left( out.statusCode, 1 ) == 2 ) {
			out.success= true;
		}
		// parse response 
		try {
			out.data= deserializeJSON( out.response );
			if ( isStruct( out.data ) && structKeyExists( out.data, "error" ) ) {
				out.success= false;
				out.error= out.data.error;
			} else if ( isStruct( out.data ) && structKeyExists( out.data, "status" ) && out.data.status == 400 ) {
				out.success= false;
				out.error= out.data.detail;
			}
		} catch (any cfcatch) {
			out.error= "JSON Error: " & cfcatch.message & " " & cfcatch.detail;
		}
		if ( len( out.error ) ) {
			out.success= false;
		}
		return out;
	}

	string function structToQueryString(required struct stInput, string sUrl= "", boolean bEncode= true) {
		var sOutput= "";
		var sItem= "";
		var sValue= "";
		var amp= ( find( "?", arguments.sUrl ) ? "&" : "?" );
		for ( sItem in stInput ) {
			sValue= stInput[ sItem ];
			if ( !isNull( sValue ) && len( sValue ) ) {
				if ( bEncode ) {
					sOutput &= amp & sItem & "=" & urlEncodedFormat( sValue );
				} else {
					sOutput &= amp & sItem & "=" & sValue;
				}
				amp= "&";
			}
		}
		return sOutput;
	}

}
