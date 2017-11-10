Storage.prototype.keys = function(filter){
    var keys = [];
    // console.log(typeof filter);
    
    if ((typeof filter) == 'undefined') {
	filter = function(){ return true }
    } else if ((typeof filter) == 'string') {
	// console.log('String')
	var re = new RegExp(filter);
	filter = function(e, i){ return e.match(re) }
    } else if (filter instanceof RegExp) {
	// console.log('RegExp');
	var re = filter;
	filter = function(e){ return e.match(re) }
    } else if (filter instanceof Function) {
	// console.log('Function')
    };
    
    for (i = 0; i < this.length; i++) { var k = localStorage.key(i); if (filter(k, i)) { keys.push(k) } }
    return keys.sort();
}

Storage.prototype.values = function(filter) {
    var s = this;
    var keys = s.keys(filter);
    var values = [];

    keys.forEach(function(e, i){ values.push(s.getData(e)) })
    return values;
};


Storage.prototype.getData = function(){
    var s = this;
    var args = Array.prototype.slice.call(arguments);
    var o = {};

    args.forEach(function(id) {
	var d = s.getItem(id);
	if (d) { o = Object.assign(o, JSON.parse(d)) } 
    });
    return o
}

Storage.prototype.setData = function(id, data, merge){
    var s = this;
    return merge ?
	s.setItem(id, JSON.stringify(Object.assign(data, s.getData(id))))
	: s.setItem(id, JSON.stringify(data))
}

Storage.prototype.setDataFromURL = function(url, id, callback, merge){
    var s = this;

    if (arguments[2] instanceof Function) { callback = arguments[2] }
    if (typeof arguments[2] === 'boolean')  { merge = arguments[2]; callback = undefined }
    if (typeof arguments[3] === 'boolean')  { merge = arguments[3] }
    
    if (callback && this.getItem(id)) { callback(this.getData(id)) }
    
    return $.get(url, function(d){
	s.setData(id, d, merge)
	if (callback) { callback(d) }
    })
};

Storage.prototype.getOrFetch = function(id, url, callback){
    var s = this;
    if (arguments[2] instanceof Function) { callback = arguments[2] }

    var d = s.getItem(id);

    if (d && JSON.parse(d)) {
	callback(d)
	// this is not good; should return a promise
	return d;
    }
    
    return $.get(url, function(d){
	s.setData(id, d)
	if (callback) { callback(d) }
    })
}


/****************************************************************************************************

    getData(id)

gets data from storage and parses it via JSON; with multiple id's it MERGES the data. Use values() to get multiple values as an array.

    setData(id, data[, merge])

sets data into storage after encoding it it as JSON. If 'merge' is true, it merges the data with 
existing stored data.

    setDataFromURL(url, id[, callback][, merge])

sets data into storage from data retrieved from 'url'. Executes 'callback' immediately, and again
after retrieving the remote data. If 'merge'  is true, it merges the data with existing stored data.

*****************************************************************************************************/
