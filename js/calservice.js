Namespace('calserv');

/*
Singleton for calservice data access
requirements:
	Namespace.js - version 1.1
	jquery - version 1.6.4
*/
			
calserv.calserv = {
	_init: false,
	_baseURL: "",
	_dateMax: "",
	_category: "",								
	// date to string we can parse 
	_getDateStr: function(date){
		dateStr = (date.getMonth() + 1) + '-' + date.getDate() + '-' + date.getFullYear();
		return dateStr;
	},
	setCategory: function(cat){
		this._category = cat;
	},
	getCategory: function(){
		return this._category;
	},
	setBaseURL: function(url){
		baseURL = url; 
	},
	getEventDetails: function(){
	},
	getDateMax: function(){
		return this._dateMax;
	},
	getEvent: function(calId, calDate, cb){
		var requestUrl = baseURL + "?method=getevent&calid=" + calId  + "&eventAsText=false&date=" + this._getDateStr(calDate);
		var result = new Object();

		var jqxhr = $.ajax(requestUrl).done(function(data){
			result.success = true;
			result.data = $.parseJSON(data);
			cb(result);
		}).fail(function(){
			result.success = false;
			cb(result);
		});
	},
	getEvents: function(dateFrom, category, limit, featured, cb){
		var result = new Object();
		var me = this;
		var requestUrl = baseURL + "?method=getEvents&limit=" + limit + "&nearestDay=true";
				
		// add date from to request
		if (typeof dateFrom !== 'undefined' && dateFrom != null){
			requestUrl = requestUrl + "&from=" + this._getDateStr(dateFrom);
		}
				
		// add category to request
		if (typeof category !== 'undefined' && category != null){
			if(!isNaN(category)){
				requestUrl = requestUrl + "&catID=" + category;	
				if (typeof featured !== 'undefined' && featured != null){
					requestUrl = requestUrl + "&featured=" + featured;
				} else { 
					requestUrl = requestUrl + "&featured=false";
				}
			} else {
				if (category == 'featured'){
					requestUrl = requestUrl + "&featured=true";
				} else {
					requestUrl = requestUrl + "&featured=false";
				}
			}
		}					
					
		var jqxhr = $.ajax(requestUrl).done(function(data){
			result.success = true;
			result.data = $.parseJSON(data);							
			
			if (result.data.length == 0){
				me._dateMax = dateFrom;
			} else {
				// set the global dateMax var			
				var lastEvent = result.data[result.data.length - 1];
				me._dateMax = new Date(lastEvent.YEAR, (lastEvent.MONTH - 1), lastEvent.DAY);
				me._dateMax.setDate(me._dateMax.getDate()+1);
			}
			cb(result);
		}).fail(function() { 
			result.success = false;
			cb(result);
		});   
	},
	getCategories: function(cb){
		var result = new Object();
		result.success = true;
		
		var requestUrl = baseURL + "method=getCategories";
		var jqxhr = $.ajax(requestUrl).done(function(data) {
			result.data = $.parseJSON(data); 
			cb(result);
		}).fail(function(){ 
			result.success = false;
			cb(result);
		});
	},
	getDayString: function(d){
		var strDay = "";
		switch(d.getDay())
		{
			case 0:
				strDay = "Sunday";
				break;
			case 1:
				strDay = "Monday";
				break;
			case 2:
				strDay = "Tuesday";
				break;
			case 3:
				strDay = "Wednesday";
				break;
			case 4:
				strDay = "Thursday";
				break;
			case 5:
				strDay = "Friday";
				break;
			case 6:
				strDay = "Saturday";
				break;
		}
		return strDay;
	},
	getMonthString: function(d){
		var strMonth = "";
		switch(d.getMonth())
		{
			case 0: 
				strMonth = "Jan";
				break;
			case 1:
				strMonth = "Feb";
				break;
			case 2: 
				strMonth = "Mar";
				break;
			case 3:
				strMonth = "Apr";
				break;
			case 4:
				strMonth = "May";
				break;
			case 5:
				strMonth = "Jun";
				break;
			case 6:
				strMonth = "Jul";
				break;
			case 7:
				strMonth = "Aug";
				break;
			case 8:
				strMonth = "Sep";
				break;
			case 9:
				strMonth = "Oct";
				break;
			case 10:
				strMonth = "Nov";
				break;
			case 11:
				strMonth = "Dec";
				break;
		}
		return strMonth;
	}
}