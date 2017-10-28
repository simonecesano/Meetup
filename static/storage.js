Storage.prototype.getData = function(id){
    var d = this.getItem(id)
    if (d) { return JSON.parse(d) } else { return undefined };
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


/****************************************************************************************************

    getData(id)

gets data from storage and parses it via JSON

    setData(id, data[, merge])

sets data into storage after encoding it it as JSON. If 'merge' is true, it merges the data with 
existing stored data.

    setDataFromURL(url, id[, callback][, merge])

sets data into storage from data retrieved from 'url'. Executes 'callback' immediately, and again
after retrieving the remote data. If 'merge'  is true, it merges the data with existing stored data.

*****************************************************************************************************/
